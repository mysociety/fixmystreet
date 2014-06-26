---
layout: page
title: Installation troubleshooting
---

# Installation troubleshooting

<p class="lead">
  If you've installed FixMyStreet using the 
  <a href="{{ site.baseurl }}install/install-script">installation script</a>
  or the 
  <a href="{{ site.baseurl }}install/ami">AMI</a>, you should be good to go.
  However, if you've done a 
  <a href="{{ site.baseurl }}install/manual-install">manual install</a>, 
  sometimes you might bump into a problem if your system is different from
  what FixMyStreet expects. These hints might help.
</p>

## Common Problems

* [locale](#locale): must be installed
* [template caching](#template-caching)
* [Image::Magick perl module](#image-magick)
* [missing Perl modules](#missing-perl-modules)
* [502 Bad Gateway error on EC2](#bad-gateway-error-on-ec2)
* [No styling (CSS)](#no-styling)
* [Bad YAML format in config settings](#bad-yaml): no response or 500 error
* [Change of config being ignored](#requires-restart): requires restart


<a name="locale"> </a>

### locale: must be installed

By default, FixMyStreet uses the `en_GB.UTF-8` 
<a href="{{ site.baseurl }}glossary/#locale" class="glossary__link">locale</a>.
If it is not installed then it may not start. You need this locale on your
system even if you're planning on running your site in a different language.

If you've changed the language or languages you're supporting, you must have
the appropriate locales installed for each of those too.

Check to see what locales your system currently supports with:

<pre><code>locale -a
</code></pre>

<a name="template-caching"> </a>

### Template caching

FixMyStreet caches compiled 
<a href="{{ site.baseurl }}glossary/#template" class="glossary__link">templates</a>
alongside the source files, so the `templates/web/` directory needs to be writable
by the process that is running FixMyStreet.

When everything is running OK, you'll see compiled template files with a
`.ttc` suffix appearing alongside the `.html` ones.

<a name="image-magick"> </a>

### Image::Magick perl module

If your OS has a way to install a binary version of `Image::Magick` then we recommend
that you do that rather than install via CPAN.

<a name="missing-perl-modules"> </a>

### Missing Perl modules

We think we've included all the modules you should need to run and develop
FixMyStreet on your machine but if we've missed one, please let us know. If you
need a new module for something you're developing, please get in touch as
adding things to carton (the mechanism FixMyStreet uses to manage Perl
dependencies) is currently not as simple as we would like.

<a name="bad-gateway-error-on-ec2"> </a>

### 502 Bad Gateway error on EC2

There's a known problem with Amazon's **micro** instance not having
enough memory when FixMyStreet's cron jobs run. See
[more about the AMI]({{ site.baseurl }}install/ami/) and 
[this GitHub ticket](https://github.com/mysociety/fixmystreet/issues/640).

The gateway fails once the fastcgi process dies. This doesn't occur if the
server has enough memory.

<a name="no-styling"> </a>

### No styling (CSS)

FixMyStreet's stylesheets are built using SASS -- the `.css` files themselves
must be created (they are not shipped as compiled files in the repo). The
installation process does this for you, but if you did a manual install
and forgot to do it, or you've changed the `.scss` files and those changes
aren't showing up, do `bin/make_css` to create them.

<a name="bad-yaml"> </a>

### Bad YAML format in config settings: no response or 500 error

When you change any of the [config settings]({{ site.baseurl }}customising/config/)
in `conf/general.yml` (which you will do!), make sure you don't break the YAML
format. If FixMyStreet can't read that file cleanly, it may time out, causing fastcgi
to eventually respond with a 500 Internal Server Error.

There are YAML lint tools available for checking the well-formedness of YAML files.
Remember that your config settings may include sensitive information (your database
password, for example) so be sensible before using online validators.

Simple things to be wary of: always quote strings that themselves contain a colon, 
be sure to close any open quotes, and avoid using tabs.

<a name="requires-restart"> </a>

### Change of config being ignored: requires restart

If you make changes (such as editing the `conf/general.yml` file) while FixMyStreet
is running, you may need to restart the process for the change to take effect.

For example, restart the Catalyst FastCGI server with:

<pre><code>sudo /etc/init.d/fixmystreet restart
</code></pre>

