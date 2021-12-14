---
layout: page
title: Docker
---

# FixMyStreet with Docker (development)

<p class="lead">
  You can use Docker and Docker Compose to get up and running quickly
  with FixMyStreet.
</p>

This is just one of [many ways to install FixMyStreet]({{ "/install/" | relative_url }}).

If you have Docker and Docker Compose installed, then the following should
set up a working FixMyStreet installation, with containers for the application,
database, memcached and webserver:

    docker/compose-dev up

Note that the setup step can take a long time the first time, and Docker does
not output the ongoing logs. While it is running, you can run `docker logs
docker_setup_1 -f` in another terminal to watch what it is doing.

## Serving with HTTPS

Some client-side features (such as Geolocation API) are only available when
the site is requested in a secure context (HTTPS). To use these features on
your development, you’ll need to serve and visit FixMyStreet over HTTPS.

First, generate a self-signed SSL certificate and keyfile with something like:

    openssl req -x509 -newkey rsa:4096 -sha256 -nodes -keyout docker/ssl.key -out docker/ssl.crt -subj "/CN=My local CA" -days 3650

Create a file at `docker/.env` with the following content:

    SERVER_ARGUMENTS='--listen :3000:ssl --ssl-cert=docker/ssl.crt --ssl-key=docker/ssl.key'

When you next run `docker/compose-dev up`, your custom `$SERVER_ARGUMENTS` will
be passed to the underlying `script/server` command, and FixMyStreet will be
accessible, with SSL, on eg: <https://fixmystreet.127.0.0.1.xip.io:3000>.

Note: You will likely need to force your browser to accept the self-signed
certificate, before it will let you visit the site.

## Installation complete... now customise

You should then proceed to [customise your installation](/customising/).
