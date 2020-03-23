<p align="center">  
<img src="https://user-images.githubusercontent.com/3514405/76737891-e0dc9180-6769-11ea-85a4-a8b5bf26d122.png" />
</p>
<p align="center"><strong>Neh</strong></p>
<p align="center">The super small and simple nginx microservice/api maker!</p>
<br/>
<br/>  

**Ever wanted a quick webhook or a small API without writing an entire server?**  
Introducing Neh, a simple program executor for nginx.  

With Neh you can:
  * Hook up a nginx location directive to any program or script
  * Receive the headers as env variables
  * Receive the request body as stdin
  * Write headers through file descriptor #3
  * Send commands like `END_REQUEST` to Neh on file descriptor #4
  * Do just about anything you want for an endpoint, really fast!

And all of that with just two lines in your config!

[Check out my blog post for more information!](https://bram.dingelstad.xyz/blog/introducing-neh)

_Keep in mind that Neh is in alpha and **should not be run in production**_

## Getting started

Make sure your location directive of choice looks like this:

 ```nginx
location /hooks/test {
    set $execute_file /home/user/script.sh; # The path to the script you want to execute
    content_by_lua_file /usr/lib/neh/neh.lua; # The path to Neh
}
```

Then create the script file:

```bash
cd
cat <<EOF > ./script.sh
#!/bin/bash
echo Hello world!
EOF
chmod +x ./script.sh
```

Quickly reload your nginx config and checking if its correct `sudo nginx -t && sudo systemctl reload nginx`
Now if you go to http://example.com/hooks/test you will see: `Hello world!`.  
Congratz! You just set up your first Neh!

Just make sure that `www-data` or whatever user is running your nginx instance can access the script!

## Installing
You can install it through this simple oneliner:
```bash
curl https://raw.githubusercontent.com/oap-bram/neh/master/install.sh | sh
```
You can also inspect the [install file](https://raw.githubusercontent.com/oap-bram/neh/master/install.sh) if you want to.

## More examples
Here are some more examples of what you can do with Neh.

### GitHub webhook

I wrote an [elaborate blog post](https://bram.dingelstad.xyz/blog/introducing-neh) with a nice example too with GitHub hooks, so check it out there!

### Bluring an image
With the following script, Neh transform a sent image into a blurred one. (Given you have ImageMagick installed on your system)

```bash
#!/bin/bash
convert - -blur 0x10 - # Convert data from stdin, blur and write to stdout

```
You can post the file as following:
```bash
curl https://example.com/your/endpoint --data-binary @./image.jpg -o ./blurred.jpg
```

### Returning random bits or a hash
With the following script, Neh get's some random bits and returns them as a response
```bash
#!/bin/bash
dd if=/dev/urandom bs=1K count=1
```

Or if you want a random (md5) hash:
```bash
dd if=/dev/urandom bs=1K count=1 | md5sum | cut -d ' ' -f1
```

### Return a webpage rendered by Ruby
```ruby
headers_fd = IO.sysopen('/proc/self/fd/3', 'w')
headers = IO.new(headers_fd)

headers << "Content-Type: text/html\n"
headers.flush

print '<h1>Hello world</h1>'
print '<p>This is a webpage</p>'
```

### Quickly save some data with Python
```python
#!/usr/bin/env python
import sys

with open("/tmp/file.txt", "a") as file:
    for line in sys.stdin:
        file.write(line)
```
You can then write to the endpoint using the following curl:
```bash
curl -sL https://example.com/your/endpoint --data-binary '{"hello": "world"}'
```

Do you have some cool implementations? Please share them with me by sending me a <a href="mailto:hey+a_cool_neh_implementation@hexli.me?subject=I got this cool Neh Implementation">friendly message</a>!

## Debugging

For debugging you can tail your nginx `error.log` usually found at `/var/log/nginx/error.log`.
If you want to debug `/usr/lib/neh/neh.lua` use the included print version and/or take a look at the [openresty docs](https://github.com/openresty/lua-nginx-module).

## Troubleshooting

I had some trouble installing it on some of my servers because of an error relating to `posix.ctype`.
It has to do with some libraries not linking properly on some distros. Apply the solution [here](https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=891541#15).

## Contributing

Feel free to open a pull request or an issue if you want!
If this gets out of hand I'll setup some structure using GitHub.

## TODO

* Comprehensive documentation
* Unit testing to guarantee quality
* Actual testing from developers/users for feedback
* Friendly error messages in logs and in responses
* Production guarantees

I could use all the help you can throw at me, so if you can help with the above let me know!

## License

See the [LICENSE](/LICENSE) for more details.

---
<sup>Sheep by MHD AZMI DWIPRANATA from the Noun Project</sup>
