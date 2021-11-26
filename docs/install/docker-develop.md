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

## Installation complete... now customise

You should then proceed to [customise your installation](/customising/).
