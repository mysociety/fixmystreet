---
layout: page
title: Installing
---

# Manual installation

<p class="lead">
  This page describes how to install the FixMyStreet platform manually.
  You can use this if you're used to setting up web applications &mdash;
  but the other installation options may be easier:</p>

Note that this is just one of
[many ways to install FixMyStreet]({{ "/install/" | relative_url }})
(the other ways are easier!).


## Manual installation

If you prefer to set up each required component of FixMyStreet
yourself, proceed with the instructions below.

### 1. Get the code

Fetch the latest version from GitHub:

{% highlight bash %}
$ mkdir FixMyStreet
$ cd FixMyStreet
$ git clone --recursive https://github.com/mysociety/fixmystreet.git
$ cd fixmystreet
{% endhighlight %}

### 2. Install prerequisite packages

#### a. Debian / Linux

If you're using Debian or Ubuntu, then the packages to install required
dependencies are listed in `conf/packages.generic`. To install all of them you
can run e.g.:

{% highlight bash %}
$ sudo xargs -a conf/packages.generic apt-get install
{% endhighlight %}

A similar list of packages should work for other Debian-based distributions.
(Please let us know if you would like to contribute such a package list or
instructions for other distributions.)

#### b. Mac OS X

Install either MacPorts or HomeBrew (you might well have one already), and then
use the command below to install a few packages that FixMyStreet needs, for
which it's much simpler to install via a packaging system.

##### i. MacPorts

{% highlight bash %}
$ port install gettext p5-locale-gettext p5-perlmagick jhead postgresql91-server
{% endhighlight %}

##### ii. HomeBrew

{% highlight bash %}
$ brew install gettext perlmagick jhead postgresql
$ brew link gettext --force
{% endhighlight %}

<div class="attention-box">
gettext needs to be linked for the Locale::gettext Perl module to install; you
can unlink gettext once everything is installed.
</div>

#### c. Other

You need Perl 5.8, ImageMagick with the perl bindings, and gettext.
If you're expecting a lot of traffic it's recommended that you install memcached: <http://memcached.org/>

### 3. Create a new PostgreSQL database

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
you will need to investigate [how to allow access to your PostgreSQL database]({{ "/install/database" | relative_url }}).

### 4. Install required dependencies, and other setup

FixMyStreet uses a number of Perl modules from CPAN; to install them,
and perform other set up functions, run:

{% highlight bash %}
$ script/setup
{% endhighlight %}

This should tell you what it is doing as it goes. It takes some time, so
feel free to continue with further steps whilst it's running.

<div class="attention-box helpful-hint">
<!-- Below hopefully not needed as installed p5-locale-gettext above
<p>Note, with MacPorts you might have to specify some compilation PATHs:</p>
<pre><code>C_INCLUDE_PATH=/opt/local/include LIBRARY_PATH=/opt/local/lib bin/install_perl_modules</code></pre>
-->
<p>It is possible you may need to install some source packages to allow some of
the included modules to be built, including expat (libexpat1-dev), postgresql
(postgresql-server-dev-8.4), or the GMP math library (libgmp3-dev).</p>
</div>

As well as installing dependencies, this script compiles our CSS (using
`bin/make_css`), installs the database schema (using `bin/update-schema`),
and compiles any translation `.mo` files (using `commonlib/bin/gettext-makemo`).

### 5. Set up config

The settings for FixMyStreet are defined in `conf/general.yml` using the YAML
markup language. There are some defaults in `conf/general.yml-example` which
you should copy to `conf/general.yml`; note that if you are using the Vagrant 
environment, a simple `conf/general.yml` file should already have been
configured for you.

{% highlight bash %}
$ cp conf/general.yml-example conf/general.yml
{% endhighlight %}

The bare minimum of settings you will need to fill in or update are:

* [FMS_DB_PASS]({{ "/customising/config/#fms_db_pass" | relative_url }}) -- this is the password for the database. (Also obviously change any other database settings you did differently here.)
* [BASE_URL]({{ "/customising/config/#base_url" | relative_url }}) -- for using the development server, set to `'http://localhost:3000/'`. This is the URL of the homepage of your FixMyStreet installation.
* [MAPIT_URL]({{ "/customising/config/#mapit_url" | relative_url }}) -- for the development server, set to `'http://localhost:3000/fakemapit/'`. This would be the URL of a MapIt installation, as and when you use one.

Some others you might want to look at, though the defaults are enough for it to run:

* [EMAIL_DOMAIN]({{ "/customising/config/#email_domain" | relative_url }}) -- the email domain that emails will be sent from
* [CONTACT_EMAIL]({{ "/customising/config/#contact_email" | relative_url }}) -- the email address to be used on the site for the contact us form.
* [DO_NOT_REPLY_EMAIL]({{ "/customising/config/#do_not_reply_email" | relative_url }}) -- the email address to be used on the site for e.g. confirmation emails.
* [STAGING_SITE]({{ "/customising/config/#staging_site" | relative_url }}) -- if this is 1 then all email (alerts and reports) will be sent to the contact email address. Use this for development sites.
* [PHOTO_STORAGE_OPTIONS.UPLOAD_DIR]({{ "/customising/config/#upload_dir" | relative_url }}) -- this is the location where images will be stored when they are uploaded. It should be accessible by and writeable by the FixMyStreet process.
* [GEO_CACHE]({{ "/customising/config/#geo_cache" | relative_url }}) -- this is the location where Geolocation data will be cached. It should be accessible by and writeable by the FixMyStreet process.

If you are using Bing or Google maps you should also set one of
[BING_MAPS_API_KEY]({{ "/customising/config/#bing_maps_api_key" | relative_url }}) or
[GOOGLE_MAPS_API_KEY]({{ "/customising/config/#google_maps_api_key" | relative_url }}).

### 6. Set up some required data

You need to generate the data used for the `/reports` page (this is run by the
crontab, but to have it working from the start, we can run the script
manually).

{% highlight bash %}
$ bin/update-all-reports
{% endhighlight %}

### 7. Run

The development server can now hopefully be run with:

{% highlight bash %}
$ script/server
{% endhighlight %}

The server will be accessible as <http://localhost:3000/>, and will
automatically restart if you update the code or `general.yml`.

### Post-install: Things you might want to change

#### Next Steps

* Create a superuser with the `bin/createsuperuser` script to access admin site.
* [Customise your install using Templates, CSS and a Cobrand module](/customising/).
* Add contact details for authorities and categories using the admin interface.

#### Tile server

You will also need a tile server to serve up map tiles. FixMyStreet can
currently use tile servers such as Bing, OpenStreetMap and Google, defaulting
to OpenStreetMap.

#### Geocoding

Finally, you will need a geolocation service to turn addresses into longitude
and latitudes. FixMyStreet currently includes code to use Bing, Google, and
OpenStreetMap geolocation services, again defaulting to OpenStreetMap.

#### Cron jobs

There is an example crontab in `conf/crontab-example`. You can use that as a
base for your own user crontab.

### Deployment

For <a href="{{ "/glossary/#production" | relative_url }}" class="glossary__link">production</a>
use of FixMyStreet, we suggest you use Apache or nginx, with either FastCGI
or Plack/PSGI.

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
nginx, you need to run the application service separately - the
`conf/sysvinit.example` or `conf/systemd.example` files are example scripts you
could use to run it as a daemon.

#### Check it's working

At this point you should be able to restart the webserver and see your
FixMyStreet installation at the configured URL. See our
[testing page]({{ "/install/testing/" | relative_url }}) on running the test
suite.

## Problems?

See some [troubleshooting hints]({{ "/install/troubleshooting/" | relative_url }}) if
something's not working for you.

## When you've finished

Please see the instructions for [updating your code](/updating/) once it's installed.

If you want to know which bits of FixMyStreet are in which directory, see this
[summary of the directory structure](/directory_structure).
