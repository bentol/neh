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
  * Write headers through file descriptor #4
  * Do just about anything you want for an endpoint, really fast!

 And all of that with just two lines in your config!

## Getting started

Make sure your location directive of choice looks like this:

 ```
server {
    server_name example.com;

    location /hooks/test {
        set $execute_file /home/user/script.sh; # The path to the script you want to execute
        content_by_lua_file /usr/lib/neh/neh.lua; # The path to Neh
        
        ...
    }
    
    ...
}
```

Then create the script file:

```
cd
cat <<EOF > ./script.sh
#!/bin/bash
echo Hello world!
EOF
chmod +x ./script.sh
```

Now if you go to http://example.com/hooks/test you will see: `Hello world!`.  
Congratz! You just set up your first Neh!

Just make sure that `www-data` or whatever user is running your nginx instance can access the script!

[TODO]: # (Add a section with more examples)

## Installing
You can install it through this simple oneliner:
```
curl https://raw.githubusercontent.com/oap-bram/neh/master/install.sh | sh
```
You can also inspect the [install file](https://raw.githubusercontent.com/oap-bram/neh/master/install.sh) if you want to.

## License

See the [LICENSE](/LICENSE) for more details.



---
<sup>Sheep by MHD AZMI DWIPRANATA from the Noun Project</sup>
