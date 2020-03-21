local posix = require 'posix'
local unistd = require 'posix.unistd'
local stdlib = require 'posix.stdlib'
local fcntl = require 'posix.fcntl'
local wait = require 'posix.sys.wait'
local signal = require 'posix.signal'

local neh = ngx.shared.neh

function print(...)
    ngx.log(0, ...)
end

function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '\''..k..'\'' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

function formatHeader(header)
    header = header:gsub('^%l', string.upper)
    header = header:gsub('-%l', string.upper)
    return header
end

OR, XOR, AND = 1, 3, 4
function bitoper(a, b, oper)
   local r, m, s = 0, 2^52
   repeat
      s,a,b = a+b+m, a%m, b%m
      r,m = r + m*oper%(s-a-b), m/2
   until m < 1
   return r
end

function trim(s)
   return s:match'^()%s*$' and '' or s:match'^%s*(.*%S)'
end

function split(string, delimiter)
    array = {}
    for part in string:gmatch('[^' .. delimiter .. ']+') do
        table.insert(array, part)
    end
    return array
end

function closePipes(array)
    for _, pipe in ipairs(array) do
        unistd.close(pipe)
    end
end

-- In a seperate "light" thread, can't access local variables or functions
function onAbort()
    local neh = ngx.shared.neh
    local run_child = neh:get(tostring(ngx.start_time) .. '-' .. 'run_child')
    local output_child = neh:get(tostring(ngx.start_time) .. '-' .. 'output_child')

    neh:delete(tostring(ngx.start_time) .. '-' .. 'run_child')
    neh:delete(tostring(ngx.start_time) .. '-' .. 'output_child')

    if run_child ~= nil then
        signal.kill(run_child, signal.SIGKILL)
        signal.kill(output_child, signal.SIGKILL)
    end

    ngx.exit(ngx.HTTP_CLOSE)
end

function writeBodyToProgram(write)
    posix.fcntl(write, fcntl.F_SETFL, bitoper(0, fcntl.O_NONBLOCK, OR))
    -- NOTE: Disable Expect header because it messes with giving a valid response by
    --       returning 100 Continue response
    ngx.req.clear_header('Expect') 

    ngx.req.read_body()
    local data = ngx.req.get_body_data()
    local filename = ngx.req.get_body_file()

    if data ~= nil then
        unistd.write(write, data)
    elseif data == nil and filename ~= nil then
        local file = posix.open(filename, bitoper(0, posix.O_RDONLY, OR))
        local byte = nil
        local buffer_size = 1024 * 10
        local size = unistd.lseek(file, 0, unistd.SEEK_END)

        unistd.lseek(file, 0, unistd.SEEK_SET)

        local total = 0

        while(true) do
            ngx.sleep(.01)
            byte = unistd.read(file, buffer_size)
            total = total + byte:len()
            if byte == nil then break end
            unistd.write(write, byte) 
            if byte:len() < buffer_size then break end
        end

        posix.fcntl(write, fcntl.F_SETFL, 0)

        unistd.close(file)
    end
end

function runProgram(read, program_write, header_write)
    unistd.dup2(read, posix.STDIN_FILENO)
    unistd.dup2(program_write, posix.STDOUT_FILENO)
    unistd.dup2(program_write, posix.STDERR_FILENO)
    unistd.dup2(header_write, 4)

    local request_headers, err = ngx.req.get_headers()

    for key, value in pairs(request_headers) do
        stdlib.setenv(string.upper(key), value)
    end

    stdlib.setenv('URL', ngx.var.request_uri)

    unistd.exec(ngx.var.execute_file , {})
end

function awaitHeaders(header_read)
    posix.fcntl(header_read, fcntl.F_SETFL, bitoper(0, fcntl.O_NONBLOCK, OR))

    local buffer = ''
    while(true) do
        ngx.sleep(.01)
        if ngx.headers_sent then break end
        local out, read_err = unistd.read(header_read, 1)
        if out ~= nil then
            if out:byte() == 10 then
                local data = split(buffer, ':')
                local header = trim(data[1])
                local value = trim(data[2])

                if ngx.headers_sent then break end
                ngx.header[header] = value
                buffer = ''
            else
                buffer = buffer .. out
            end
        else
            ngx.sleep(.1)
        end
    end
end

function awaitOutput(run_child, program_read)
    posix.fcntl(program_read, fcntl.F_SETFL, bitoper(0, fcntl.O_NONBLOCK, OR))

    ngx.header['Server'] = 'Neh alphav1'
    ngx.header['Content-Type'] = 'text/plain'

    while(true) do
        ngx.sleep(.01)
        local pid, wait_err = wait.wait(run_child, bitoper(0, wait.WNOHANG, OR))
        local out, read_err = unistd.read(program_read, 1024)

        if out ~= nil then
            if socket == nil then
                ngx.send_headers()
                ngx.flush(true)
    
                socket, err = ngx.req.socket(true)

                if socket == nil then
                    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
                end
            end

            -- TODO: Check if this is faster with ngx.print
            local bytes, err = socket:send(string.format('%x', out:len()) .. '\r\n' .. out .. '\r\n')

            if err == 'closed' then
                break
            end
        else
            if wait_err == 'No child processes' then
                if socket ~= nil then
                    socket:send('0\r\n\r\n')
                end
                break
            end
        end
    end
end

local ok = ngx.on_abort(onAbort)
if ok ~= 1 then
    print('Something went wrong setting onAbort. Please check if `lua_check_client_abort` value is set to on')
end

local socket 

local read, write = posix.pipe()
local program_read, program_write = posix.pipe()
local header_read, header_write = posix.pipe()

local output_child = unistd.fork()
if output_child == 0 then
    local write_child = unistd.fork()
    if write_child == 0 then
        writeBodyToProgram(write)
        closePipes({read, write, program_read, program_write, header_read, header_write})
        posix._exit(0)
    end

    local run_child = unistd.fork()
    if run_child == 0 then
        closePipes({write, program_read, header_read })
        runProgram(read, program_write, header_write)
    end

    neh:set(tostring(ngx.start_time) .. '-' .. 'run_child', run_child)
    neh:set(tostring(ngx.start_time) .. '-' .. 'output_child', output_child)

    closePipes({read, write, program_write, header_write})
    ngx.thread.spawn(awaitHeaders, header_read)

    wait.wait(write_child)

    local output_thread = ngx.thread.spawn(awaitOutput, run_child, program_read)
    ngx.thread.wait(output_thread)
    closePipes({read, write, program_read, program_write, header_read, header_write})
    posix._exit(0)
end

closePipes({read, write, program_read, program_write, header_read, header_write})

while (true) do
    local _, err = wait.wait(output_child)
    if err == 'No child processes' then break end
end
neh:delete(tostring(ngx.start_time) .. '-' .. 'run_child')
neh:delete(tostring(ngx.start_time) .. '-' .. 'output_child')
