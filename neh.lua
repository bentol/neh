local posix = require 'posix'
local unistd = require 'posix.unistd'
local stdlib = require 'posix.stdlib'
local fcntl = require 'posix.fcntl'
local wait = require 'posix.sys.wait'

local socket 

local read, write = posix.pipe()
local output_read, output_write = posix.pipe()
local header_read, header_write = posix.pipe()



function print(...)
    ngx.log(0, ...)
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

function writeData()
    ngx.req.read_body()
    local data = ngx.req.get_body_data()

    if data ~= nil then
        unistd.write(write, data)
    end
end

function runProgram()
    unistd.dup2(read, posix.STDIN_FILENO)
    unistd.dup2(output_write, posix.STDOUT_FILENO)
    unistd.dup2(output_write, posix.STDERR_FILENO)
    unistd.dup2(header_write, 4)

    local headers, err = ngx.req.get_headers()
    for key, value in pairs(headers) do
        stdlib.setenv(string.upper(key), value)
    end

    stdlib.setenv('URL', ngx.var.request_uri)

    -- unistd.close(output_read)
    unistd.exec('/home/bram/script.sh', {})
    -- unistd.exec(ngx.var.execute_file , {})
end

function output(run_child)
    -- local headers = ''
    -- while(true) do
    --     local out, err = unistd.read(header_read, 1024)
    --     if err ~= nul then break end
    --     headers = headers .. out
    --     if out == nil or out:len() < 1024 then break end
    -- end
    --
    -- unistd.close(header_read)

    -- ngx.header['Content-Type'] = 'text/plain'
    -- ngx.send_headers()
    --
    -- for _, line in pairs(split(headers, '\r\n')) do
    --     local data = split(line, ':')
    --     local header = trim(data[1])
    --     local value = trim(data[2])
    --
    --     ngx.header[header] = value
    -- end

    while(true) do
        local pid, wait_err = wait.wait(run_child, bitoper(0, wait.WNOHANG, OR))
        local out, read_err = unistd.read(output_read, 1024)

        if out ~= nil then
            socket:send(out)
        elseif wait_err == 'No child processes' then
            ngx.eof()
            break
        end

        ngx.sleep(.01)
    end

end

posix.fcntl(output_read, fcntl.F_SETFL, bitoper(0, fcntl.O_NONBLOCK, OR))
posix.fcntl(output_write, fcntl.F_SETFL, bitoper(0, fcntl.O_NONBLOCK, OR))

ngx.header['Content-Type'] = 'text/plain'
ngx.send_headers()

socket = ngx.req.socket(true)

local write_child = unistd.fork()
if write_child == 0 then
    writeData()
    posix._exit(0)
end

local output_child = unistd.fork()
if output_child == 0 then

    local run_child = unistd.fork()
    if run_child == 0 then
        runProgram()
    end

    local output_thread, err = ngx.thread.spawn(output, run_child)
    ngx.thread.wait(output_thread)
    posix._exit(0)
end

while(true) do
    ::continue::
    ngx.sleep(.01)

    local pid, err = wait.wait(output_child)
    if err == 'No child processes' then
        ngx.eof()
        ngx.exit(ngx.HTTP_OK)
    end

    if err ~= nil then
        goto continue
    end
end

