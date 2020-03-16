local posix = require 'posix'
local unistd = require 'posix.unistd'
local stdlib = require 'posix.stdlib'

function print(...)
    ngx.say(...)
    ngx.flush(false)
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
    unistd.close(read)
    unistd.write(write, 'Hello?')
    unistd.write(write, 0x04)
    unistd.close(write)
end

function runProgram()
    local child = posix.fork()
    if child ~= 0 then return end

    unistd.dup2(read, posix.STDIN_FILENO)
    unistd.dup2(output_write, posix.STDOUT_FILENO)
    unistd.dup2(output_write, posix.STDERR_FILENO)

    local headers, err = ngx.req.get_headers()
    for key, value in pairs(headers) do
        stdlib.setenv(string.upper(key), value)
    end

    stdlib.setenv('URL', ngx.var.request_uri)

    unistd.close(output_read)
    unistd.execp(ngx.var.execute_file , {})
    unistd.close(output_write)
    posix._exit(1)
end

function outputThread()
    local buffer = '' 

    -- FIXME: Change this to a streaming implementation.
    --        Take a look at https://github.com/openresty/lua-nginx-module#lua_http10_buffering

    -- TODO: Add 4th file descriptor that writes to the header from the `external_file`

    while(true) do
        local out, err = unistd.read(output_read, 1024)
        if err ~= nil then break end
        buffer = buffer .. out
    end

    print(buffer)
end

local dataWriteThread, err = ngx.thread.spawn(writeData)
local programThread, err = ngx.thread.spawn(runProgram)
local outputThread, err = ngx.thread.spawn(outputThread)

local ok, res = ngx.thread.wait(dataWriteThread)
local ok, res = ngx.thread.wait(programThread)
local ok, res = ngx.thread.wait(outputThread)
