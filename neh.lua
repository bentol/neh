local posix = require 'posix'
local unistd = require 'posix.unistd'
local stdlib = require 'posix.stdlib'

function print(...)
    ngx.log(0, ...)
end

function pipe()
   local r, w = posix.pipe()
   assert(r ~= nil, w)
   return r, w
end

ngx.req.read_body()

local data = ngx.req.get_body_data()

local read, write = pipe()
local output_read, output_write = pipe()

function writeData()
    if data ~= nil then
        unistd.write(write, data)
    end
    unistd.close(write)
end

function runProgram()
    local child = posix.fork()
    if child ~= 0 then
        posix.wait(child)
        return
    end

    unistd.dup2(read, posix.STDIN_FILENO)
    unistd.dup2(output_write, posix.STDOUT_FILENO)
    unistd.dup2(output_write, posix.STDERR_FILENO)

    local headers, err = ngx.req.get_headers()
    for key, value in pairs(headers) do
        stdlib.setenv(string.upper(key), value)
    end

    stdlib.setenv('URL', ngx.var.request_uri)

    unistd.close(output_read)
    unistd.exec(ngx.var.execute_file , {})
    posix.wait(child)

    posix._exit(0)
end

function output()
    local buffer = '' 
    -- TODO: Change this to a streaming implementation.
    --        Take a look at https://github.com/openresty/lua-nginx-module#lua_http10_buffering
    unistd.close(output_write)

    while(true) do
        local out, err = unistd.read(output_read, 1024)
        if err ~= nil then break end
        buffer = buffer .. out
        if out == nil or out:len() < 1024 then break end
    end

    unistd.close(output_read)

    -- TODO: Add 4th file descriptor that writes to the header from the `external_file`
    ngx.header['Content-Type'] = 'text/plain'

    ngx.print(buffer)
    ngx.flush(false)
end



local dataWriteThread, err = ngx.thread.spawn(writeData)
local programThread, err = ngx.thread.spawn(runProgram)
local outputThread, err = ngx.thread.spawn(output)

local ok, res = ngx.thread.wait(dataWriteThread)
local ok, res = ngx.thread.wait(programThread)
local ok, res = ngx.thread.wait(outputThread)

-- vi: syntax=lua
