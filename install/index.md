---
layout: page
title: Installing
---

# Installing FixMyStreet Platform

<p class="lead">There are several options for installing the FixMyStreet platform.
The rest of this page describes how to do this manually, for people
who are used to setting up web applications, but there are two other
options that may be easier:</p>

<div class="row-fluid">
<div class="span6">
<ul class="nav nav-pills nav-stacked">
<li><a href="ami/">A FixMyStreet AMI for Amazon EC2</a></li>
<li><a href="install-script/">An install script for Debian squeeze or Ubuntu precise servers</a></li>
</ul>
</div>
</div>

Please also see the instructions for [updating your code](/updating/) once it's installed.

If you want to know which bits of FixMyStreet are in which directory, see this
[summary of the directory structure](/directory_structure).

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
you will need to investigate [how to allow access to your PostgreSQL database](database).

Now you can use the sql in `db/schema.sql` to create the required
tables, triggers and stored procedures. You will also need to run
`db/alert_types.sql` which populates the alert_types table, and
generate_secret to make a site-wide secret. For example, you might run:

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

If you're using Debian 6.0 ("squeeze") then the packages to install
some required dependencies are listed in `conf/packages.debian-squeeze` or
`conf/packages.debian-squeeze+testing`. To install all of them you can run:

    sudo xargs -a conf/packages.debian-squeeze apt-get install

A similar list of packages should work for other Debian-based
distributions.  (Please let us know if you would like to contribute
such a package list or instructions for other distributions.)

Unfortunately, Compass is not packaged in Debian squeeze (or
squeeze-backports).  You will either need to install the package
from testing, or you could install it from the Ruby gem with:

    gem install compass

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

* FMS_DB_PASS -- this is the password for the database. (Also obviously change any other database settings you did differently here.)
* BASE_URL -- for using the development server, set to `'http://localhost:3000/'`. This is the URL of the homepage of your FixMyStreet installation.
* MAPIT_URL -- for the development server, set to `'http://localhost:3000/fakemapit/'`. This would be the URL of a MapIt installation, as and when you use one.

Some others you might want to look at, though the defaults are enough for it to run:

* EMAIL_DOMAIN -- the email domain that emails will be sent from
* CONTACT_EMAIL -- the email address to be used on the site for the contact us form.
* DO_NOT_REPLY_EMAIL -- the email address to be used on the site for e.g. confirmation emails.
* STAGING_SITE -- if this is 1 then all email (alerts and reports) will be sent to the contact email address. Use this for development sites.
* UPLOAD_DIR -- this is the location where images will be stored when they are uploaded. It should be accessible by and writeable by the FixMyStreet process.
* GEO_CACHE -- this is the location where Geolocation data will be cached. It should be accessible by and writeable by the FixMyStreet process.

If you are using Bing or Google maps you should also set one of BING_MAPS_API_KEY or GOOGLE_MAPS_API_KEY.

### 6. Generate CSS

There is a script, bin/make_css, that uses Compass and sass to
convert the SCSS files to CSS files:

    bin/make_css

### 7. Run

The development server can now hopefully be run with:

     bin/cron-wrapper script/fixmystreet_app_server.pl -d --fork

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

There is an example crontab in `conf/crontab.ugly`. At the moment this is in
the format used by mySociety's internal deployment tools. To convert this to
a valid crontab the following should be done -- copy the file to somewhere else,
and:

* Replace `!!(*= $user *)!!` with the name of the user the cron should run under
* Replace `!!(* $vhost *)!!` with the path to the FixMyStreet code.

### Deployment

For production use of FixMyStreet, we suggest you use Apache or nginx, and
FastCGI. It should also be possible to run it using Plack/PSGI.

There is an example nginx configuration in `conf/nginx.conf.example`, and an
example Apache vhost configuration file in `conf/apache-vhost.conf.example` and
`conf/httpd.conf-example`, which contain a sample configuration and the
required redirect rules. If you are using Apache and the sample configuration
you will need the following modules enabled:

* mod_rewrite
* mod_proxy
* mod_expires
* mod_fastcgi

For most Linux distributions you should be able to install these using the
distribution's packaging system.

At this point you be able to restart the webserver and see your FixMyStreet
installation at the configured URL.

#### Check it's working

You can run the unit tests by running the following command in the
`fixmystreet` directory:

    bin/cron-wrapper prove -r t

These currently require that the fixmystreet cobrand is enabled in the
`ALLOWED_COBRANDS` setting, and also might assume other config is set up
correctly. Note that this may leave entries in your database at the moment and
should not be run on a live site.

The `master` branch of the repository should always be passing all tests for
our developers and on mySociety's servers.

### Common Problems

#### locale

By default FixMyStreet uses the en_GB.UTF-8 locale. If it is not installed then
it may not start

#### Template caching

FixMyStreet caches compiled templates alongside the source files so the templates
directory needs to be writable by the process that is running FixMyStreet.

#### Image::Magick perl module

If your OS has a way to install a binary version of Image::Magick then it's recommended
that you do that rather than install via CPAN.

#### Missing Perl modules

We think we've included all the modules you should need to run and develop FixMyStreet on your
machine but if we've missed one, please let us know. If you need a new module for something
you're developing, please get in touch as adding things to carton is currently not as simple
as we would like.

