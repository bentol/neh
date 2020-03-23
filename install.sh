#!/bin/bash
sudo apt install -qq -y libnginx-mod-http-lua lua-posix
sudo mkdir -p /usr/lib/neh

# Download neh.lua file for executing location directives
sudo curl -sL \
    https://raw.githubusercontent.com/oap-bram/neh/master/neh.lua \
    -o /usr/lib/neh/neh.lua

# License to let y'all know that it's mine ;)
sudo curl -sL \
    https://raw.githubusercontent.com/oap-bram/neh/master/LICENSE \
    -o /usr/lib/neh/LICENSE

# Config for nginx
sudo curl -sL \
    https://raw.githubusercontent.com/oap-bram/neh/master/neh.conf \
    -o /etc/nginx/conf.d/neh.conf
