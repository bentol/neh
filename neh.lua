local posix = require 'posix'
local unistd = require 'posix.unistd'
local stdlib = require 'posix.stdlib'
local fcntl = require 'posix.fcntl'
local wait = require 'posix.sys.wait'
local signal = require 'posix.signal'

local socket 

local request_headers, err = ngx.req.get_headers()

local read, write = posix.pipe()
local program_read, program_write = posix.pipe()
local header_read, header_write = posix.pipe()

function print(...)
    ngx.log(0, ...)
end

function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

function formatHeader(header)
    header = header:gsub("^%l", string.upper)
    header = header:gsub("-%l", string.upper)
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
    for part in string:gmatch("[^" .. delimiter .. "]+") do
        table.insert(array, part)
    end
    return array
end

function writeBodyToProgram()
    ngx.req.read_body()
    local data = ngx.req.get_body_data()

    if data ~= nil then
        unistd.write(write, data)
    end
end

function runProgram()
    unistd.dup2(read, posix.STDIN_FILENO)
    unistd.dup2(program_write, posix.STDOUT_FILENO)
    unistd.dup2(program_write, posix.STDERR_FILENO)
    unistd.dup2(header_write, 4)

    for key, value in pairs(request_headers) do
        stdlib.setenv(string.upper(key), value)
    end

    stdlib.setenv('URL', ngx.var.request_uri)

    unistd.exec(ngx.var.execute_file , {})
end

function awaitHeaders()
    posix.fcntl(header_read, fcntl.F_SETFL, bitoper(0, fcntl.O_NONBLOCK, OR))

    local buffer = ''
    while(true) do
        if ngx.headers_sent then break end
        local out, read_err = unistd.read(header_read, 1)
        if out ~= nil then
            if out:byte() == 10 then
                local data = split(buffer, ':')
                local header = trim(data[1])
                local value = trim(data[2])

                print('Setting ' .. header .. ' to ' .. value)
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

function awaitOutput(run_child)
    posix.fcntl(program_read, fcntl.F_SETFL, bitoper(0, fcntl.O_NONBLOCK, OR))

    ngx.header['Server'] = 'Neh alphav1'
    ngx.header['Content-Type'] = 'text/plain'

    while(true) do
        local pid, wait_err = wait.wait(run_child, bitoper(0, wait.WNOHANG, OR))
        local out, read_err = unistd.read(program_read, 1024)

        if out ~= nil then
            if socket == nil then
                ngx.send_headers()
                ngx.flush(true)

                socket, err = ngx.req.socket(true)
            end

            socket:send(string.format("%x", out:len()) .. '\r\n' .. out .. '\r\n')
        else
            ngx.sleep(.1)
            if wait_err == 'No child processes' then
                socket:send('0\r\n\r\n')
                break
            end
        end
    end
end


local write_child = unistd.fork()
if write_child == 0 then
    writeBodyToProgram()
    posix._exit(0)
end

wait.wait(write_child)

local output_child = unistd.fork()
if output_child == 0 then

    local run_child = unistd.fork()
    if run_child == 0 then
        runProgram()
    end

    local header_thread, err = ngx.thread.spawn(awaitHeaders)
    local output_thread, err = ngx.thread.spawn(awaitOutput, run_child)
    ngx.thread.wait(output_thread)
    posix._exit(0)
end

while(true) do
    ::continue_wait::
    ngx.sleep(.01)

    local pid, err = wait.wait(output_child)
    if err == 'No child processes' then
        print('Closing for good')
        ngx.exit(ngx.HTTP_OK)
    end

    if err ~= nil then
        goto continue_wait
    end
end
