---
layout: page
title: Installing
---

# Manual installation

<p class="lead">
  This page describes how to install FixMyStreet patform manually.
  You can use this if you're used to setting up web applications &mdash; 
  but the other installation options may be easier:</p>

Note that this is just one of 
[four ways to install FixMyStreet]({{ site.baseurl }}install/)
(the other ways are easier!).


## Manual installation

If you prefer to set up each required component of FixMyStreet
yourself, proceed with the instructions below.

### 1. Get the code

Fetch the latest version from GitHub:

{% highlight bash %}
mkdir FixMyStreet
cd FixMyStreet
git clone --recursive https://github.com/mysociety/fixmystreet.git
cd fixmystreet
{% endhighlight %}

(if you're running an old version of git, prior to 1.6.5, you'll have to clone
and then run `git submodule update --init` separately).

### 2. Create a new PostgreSQL database

FixMyStreet uses a PostgreSQL database, so install PostgreSQL first (e.g. `port
install postgresql91-server` with MacPorts, or `apt-get install postgresql-8.4`
on Debian, or install from the PostgreSQL website).

The default settings assume the database is called fms and the user the same.
You can change these if you like. Using the defaults, create a user and
database using the following (do not worry if the `CREATE LANGUAGE` step gives
an error that it already exists, it might well do depending on how your
PostgreSQL was installed):

{% highlight sql %}
$ sudo -u postgres psql
postgres=# CREATE USER fms WITH PASSWORD 'somepassword';
CREATE ROLE
postgres=# CREATE DATABASE fms WITH OWNER fms;
CREATE DATABASE
postgres=# \c fms
postgres=# CREATE LANGUAGE plpgsql;
postgres=# \q
$
{% endhighlight %}

You should be able to connect to the database with `psql -U fms fms` -- if not,
you will need to investigate [how to allow access to your PostgreSQL database]({{ site.baseurl }}install/database).

#### 2b. Install database schema

Now you can use the provided SQL in `db` to create the required
tables, triggers, and initial data. Run the following:

{% highlight bash %}
$ psql -U fms fms < db/schema.sql
...
$ psql -U fms fms < db/generate_secret.sql
...
$ psql -U fms fms < db/alert_types.sql
...
{% endhighlight %}

### 3. Install prerequisite packages

#### a. Mac OS X

Install either MacPorts or HomeBrew (you might well have one already), and then
use the command below to install a few packages that FixMyStreet needs, for
which it's much simpler to install via a packaging system.

##### i. MacPorts

    port install gettext p5.12-perlmagick jhead rb-rubygems

##### ii. HomeBrew

    brew install gettext imagemagick jhead

#### b. Debian / Linux

If you're using Debian 7 ("wheezy") then the packages to install some required
dependencies are listed in `conf/packages.debian-wheezy`. To install all of
them you can run:

    sudo xargs -a conf/packages.debian-wheezy apt-get install

A similar list of packages should work for other Debian-based
distributions.  (Please let us know if you would like to contribute
such a package list or instructions for other distributions.)

#### c. Other

You need Perl 5.8, ImageMagick with the perl bindings, gettext, and compass.
If you're expecting a lot of traffic it's recommended that you install memcached: <http://memcached.org/>

### 4. Install prerequisite Perl modules

FixMyStreet uses a number of CPAN modules; to install them, run:

    bin/install_perl_modules

This should tell you what it is installing as it goes.

It is possible you may need to install some source packages to allow some of
the included modules to be built, including expat (libexpat1-dev), postgresql
(postgresql-server-dev-8.4), and the GMP math library (libgmp3-dev).

### 5. Set up config

The settings for FixMyStreet are defined in `conf/general.yml` using the YAML
markup language. There are some defaults in `conf/general.yml-example` which
you should copy to `conf/general.yml`:

    cp conf/general.yml-example conf/general.yml

The bare minimum of settings you will need to fill in or update are:

* [FMS_DB_PASS]({{ site.baseurl }}customising/config/#fms_db_pass) -- this is the password for the database. (Also obviously change any other database settings you did differently here.)
* [BASE_URL]({{ site.baseurl }}customising/config/#base_url) -- for using the development server, set to `'http://localhost:3000/'`. This is the URL of the homepage of your FixMyStreet installation.
* [MAPIT_URL]({{ site.baseurl }}customising/config/#mapit_url) -- for the development server, set to `'http://localhost:3000/fakemapit/'`. This would be the URL of a MapIt installation, as and when you use one.

Some others you might want to look at, though the defaults are enough for it to run:

* [EMAIL_DOMAIN]({{ site.baseurl }}customising/config/#email_domain) -- the email domain that emails will be sent from
* [CONTACT_EMAIL]({{ site.baseurl }}customising/config/#contact_email) -- the email address to be used on the site for the contact us form.
* [DO_NOT_REPLY_EMAIL]({{ site.baseurl }}customising/config/#do_not_reply_email) -- the email address to be used on the site for e.g. confirmation emails.
* [STAGING_SITE]({{ site.baseurl }}customising/config/#staging_site) -- if this is 1 then all email (alerts and reports) will be sent to the contact email address. Use this for development sites.
* [UPLOAD_DIR]({{ site.baseurl }}customising/config/#upload_dir) -- this is the location where images will be stored when they are uploaded. It should be accessible by and writeable by the FixMyStreet process.
* [GEO_CACHE]({{ site.baseurl }}customising/config/#geo_cache) -- this is the location where Geolocation data will be cached. It should be accessible by and writeable by the FixMyStreet process.

If you are using Bing or Google maps you should also set one of
[BING_MAPS_API_KEY]({{ site.baseurl }}customising/config/#bing_maps_api_key) or 
[GOOGLE_MAPS_API_KEY]({{ site.baseurl }}customising/config/#google_maps_api_key).

### 6. Generate CSS

There is a script, bin/make_css, that uses Compass and sass to
convert the SCSS files to CSS files:

    bin/make_css

### 7. Run

The development server can now hopefully be run with:

     script/fixmystreet_app_server.pl -d --fork

The server will be accessible as <http://localhost:3000/>. You can run with -r
in order for the server to automatically restart when you update the code.


### Post-install: Things you might want to change

#### Next Steps

* The admin site should be protected using HTTP AUTH.
* [Customise your install using Templates, CSS and a Cobrand module](/customising/).
* Add contact details for authorities and categories using the admin interface.

#### Tile server

You will also need a tile server to serve up map tiles. FixMyStreet can
currently use Bing and OpenStreetMap tile servers, defaulting to OpenStreetMap.

#### Geocoding

Finally, you will need a geolocation service to turn addresses into longitude
and latitudes. FixMyStreet currently includes code to use Bing, Google, and
OpenStreetMap geolocation services, again defaulting to OpenStreetMap.

#### Cron jobs

There is an example crontab in `conf/crontab-example`. You can use that as a
base for your own user crontab.

### Deployment

For <a href="{{ site.baseurl }}glossary/#production" class="glossary__link">production</a>
use of FixMyStreet, we suggest you use Apache or nginx, and
FastCGI. It should also be possible to run it using Plack/PSGI, if that is
preferable.

#### Apache

There is an example Apache vhost configuration file in
`conf/apache-vhost.conf.example` and `conf/httpd.conf-example`, which contain a
sample configuration and the required redirect rules.

The sample configuration will need the following modules enabled:

* mod_rewrite
* mod_proxy
* mod_expires
* mod_fastcgi

For most Linux distributions you should be able to install these using the
distribution's packaging system.

#### nginx

There is an example nginx configuration in `conf/nginx.conf.example`. With
nginx, you need to run the FastCGI service separately - the
`conf/sysvinit.example` file is an example script you could use to run it as a
daemon. And you will need to install a FastCGI process manager:

    apt-get install libfcgi-procmanager-perl

#### Check it's working

At this point you should be able to restart the webserver and see your
FixMyStreet installation at the configured URL.

You can run the unit tests by running the following command in the
`fixmystreet` directory:

    bin/run-tests t

These currently require that the fixmystreet cobrand is enabled in the
[ALLOWED_COBRANDS]({{ site.baseurl }}customising/config/#allowed_cobrands)
setting, and also might assume other config is set up
correctly. Note that this may leave entries in your database at the moment and
should not be run on a live site.

The `master` branch of the repository should always be passing all tests for
our developers and on mySociety's servers.

## Problems?

See some [troubleshooting hints]({{ site.baseurl }}install/troubleshooting/) if
something's not working for you.

## When you've finished

Please see the instructions for [updating your code](/updating/) once it's installed.

If you want to know which bits of FixMyStreet are in which directory, see this
[summary of the directory structure](/directory_structure).
