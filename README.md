# myshift2teams
## Simple API service for organization of shifts

### What?
This is a minimal app sending messages about shifts in a organization to MS Teams. You can send a json to the *myshift* endpoint with a list of people and it will store the configuration and the initial shift in a [Redis](https://redis.io) database. Then you can update the shift or send a shift reminder to a MS Teams channel.

### How to build it?
You will need a D compiler installed (DMD/ldc/...), a C compiler and the DUB package manager. You also will need the sources of phobos library, zlib and openssl lib.

With all these elements, you only need to run `dub install` in this directory.

Alternatively, there is a [Dockerfile](Dockerfile) that you can use to build a container.

### How to run it?
In order to run myshift2teams, you must have installed zlib, openssl library and phobos. And, you'll need a running Redis database where the configuration and shifts will be stored.

Then you can execute the binary:
```
$ ./myshift2teams 
[main(----) INF] Listening for requests on http://127.0.0.1:9000
```
By default, the service will listen at 127.0.0.1:9000 but you can override this value exporting MYSHIFT\_HOST and MYSHIFT\_PORT environment variables. Also you can override the default redis address (127.0.0.1:6379) exporting REDIS\_HOST and REDIS\_PORT environment variables.

You also can use the Docker image, vg.:
```
$ docker pull frantsao/myshift2teams:latest
$ docker run -p 9000:9000 -e MYSHIFT_HOST=0.0.0.0 frantsao/myshift2teams:latest
```

Then you can send a POST to /api/myshift path with a json payload like [data.json](test/data.json). With this configuration example, the hook will be sent to a test endpoint in the same myshift service; you must change the notificationUrl with the webhook url you created in your MS Teams channel:

```
$ http POST 127.0.0.1:9000/api/myshift < data.json 
HTTP/1.1 200 OK
Content-Length: 54
Content-Type: application/json
Date: Tue, 24 May 2022 20:22:12 GMT
Keep-Alive: timeout=10
Server: vibe.d/1.16.0

{
    "OK": "Created/updated configuration"
}
```

The initial config sets the shift to the first name of the list (that is the number 0). You can set that variable to a different number:

```
$ http "127.0.0.1:9000/api/setmyshift?shift=4"
HTTP/1.1 200 OK
Content-Length: 16
Content-Type: application/json; charset=UTF-8
Date: Tue, 24 May 2022 20:24:02 GMT
Keep-Alive: timeout=10
Server: vibe.d/1.22.3

"Set shift to 4"

```

Or you simply need to move along the list:

```
$ http 127.0.0.1:9000/api/updatemyshift
HTTP/1.1 200 OK
Content-Length: 16
Content-Type: application/json; charset=UTF-8
Date: Tue, 24 May 2022 20:26:36 GMT
Keep-Alive: timeout=10
Server: vibe.d/1.22.3

"Set shift to 5"

```

Then you will send the shift reminder:

```
$ http 127.0.0.1:9000/api/sendmyshift
HTTP/1.1 200 OK
Content-Length: 24
Content-Type: application/json; charset=UTF-8
Date: Tue, 24 May 2022 20:29:11 GMT
Keep-Alive: timeout=10
Server: vibe.d/1.22.3

"Sent shift reminder to: Sergio"

```

I sent the request in the example using the wonderful [HTTPie](https://httpie.io/).

### Why?

This is a minimal evolution of [my first experiment with Dlang](https://github.com/frantsao/tortilla2teams) that solves a need we had in my team at [idealista](https://idealista.com).

### How?
This has been my documentation:
- [The D language programming web](https://dlang.org/)
- [The vibe.d library web](https://vibed.org/)
- [The Tiny Redis library web](http://adilbaig.github.io/Tiny-Redis/)
- [The Programming in D book](https://ddili.org/ders/d.en/index.html)
- [The Microsoft Teams webhooks documentation](https://docs.microsoft.com/en-us/microsoftteams/platform/webhooks-and-connectors/how-to/connectors-using)

### Status
Functional :-)

### Built With

![DMD](https://img.shields.io/badge/LDC-1.29.0-green.svg)
![DUB](https://img.shields.io/badge/DUB-1.28.0-green.svg)
![vibe.d](https://img.shields.io/badge/vibe.d-0.9.4-green.svg)
![tinyredis](https://img.shields.io/badge/tinyredis-2.3.1-green.svg)

### About
![AGPLv3](https://img.shields.io/badge/License-AGPLv3-orange)

This work is under AGPLv3 license (see see the [LICENSE](LICENSE) file).
