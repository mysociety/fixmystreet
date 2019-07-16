---
layout: page
title: Docker
---

# FixMyStreet with Docker

<p class="lead">
  You can use Docker and Docker Compose to get up and running quickly
  with FixMyStreet.
</p>

This is just one of [many ways to install FixMyStreet]({{ "/install/" | relative_url }}).

## Public images

As well as providing a `Dockerfile` which you could use as the basis of your own
customised build, we provide public [images on Docker Hub](https://hub.docker.com/u/fixmystreet/)
with a full FixMyStreet installation for each of our tagged releases.

## Docker Compose

If you have Docker and Docker Compose installed, then the following should
set up a working FixMyStreet installation, with containers for the application,
database, memcached and webserver:

    docker-compose up

You can then layer your own [cobrand-specific code](/customising/)
on top, update the configuration, or log in and make changes.

A superuser is automatically created, with email `superuser@example.org`
and password given in `docker-compose.yml`.

This basic installation uses the default cobrand, with a
(deliberately) rather garish colour scheme.

## Adding your own cobrand

If you want to map your own cobrand data into the Docker container, have a
repository/directory that contains the following (all items optional):

    my-cobrand-repo/
        templates/web/(cobrand)/
        templates/email/(cobrand)/
        perllib/FixMyStreet/Cobrand/(CoBrand.pm)
        web/cobrands/(cobrand)/

Create a docker-compose.override.yml file in the root of the fixmystreet
repository (alongside docker-compose.yml) containing:

    version: '3'

    services:
      fixmystreet:
        volumes:
          - /path/to/your/general.yml:/var/www/fixmystreet/fixmystreet/conf/general.yml
          - /path/to/my-cobrand-repo:/var/www/fixmystreet/cobrand

Now if you run `docker-compose up` it should automatically include that cobrand
within the running container.

This is a new facility, so please do feed back your thoughts.

## Database configuration

The example Docker Compose environment includes a [slightly customised Postgres container](https://github.com/mysociety/public-builds/tree/master/docker/postgres)
based on [the official image](https://hub.docker.com/_/postgres/) and localised for `en_GB`.

This will be configured the first time it is started and its data stored in a
Docker volume for persistence. The password for the `postgres` user should be set
in the `POSTGRES_PASSWORD` environment variable and made available to both the
database and application containers; along with the various `FMS_DB_*` environment
variables this will be used to ensure the correct users, permissions and databases
are created when the container starts for the first time.

### Using an external database

If you wish to host the database in an external service you can do so by updating
the various `FMS_DB_*` environment variables used by the application container and
in `general.yml`. You should not provide a `POSTGRES_PASSWORD` variable to the
application container in this case.

The application container will attempt to create the database if it doesn't already exist, so
you can either provide the user with the `CREATEDB` privilege or simply provide
an empty database and the application container will load the schema when it starts
for the first time.

## Installation complete... now customise

You should then proceed
to [customise your installation](/customising/).
