#!/bin/bash
sudo apt install -qq -y libnginx-mod-http-lua lua-posix
sudo mkdir -p /usr/lib/neh
sudo curl -sL \
    https://raw.githubusercontent.com/oap-bram/neh/master/neh.lua \
    -o /usr/lib/neh.lua
