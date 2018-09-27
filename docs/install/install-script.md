---
layout: page
title: Install script
---

# FixMyStreet Install Script

<p class="lead">
  If you have a new installation of Debian wheezy or Ubuntu precise,
  you can use an install script to set up a basic installation of
  FixMyStreet on your server.
</p>

Note that this is just one of [many ways to install FixMyStreet]({{ "/install/" | relative_url }}).

## Warning: installation changes your setup!

*Warning: only use this script on a newly installed server -- it will
make significant changes to your server's setup, including modifying
your nginx setup, creating a user account, creating a database,
installing new packages, and so on.*

## Running the script

The script to run is called [`install-site.sh`, in our `commonlib` repository](https://github.com/mysociety/commonlib/blob/master/bin/install-site.sh).
That script's usage is as follows:

    Usage: ./install-site.sh [--default] <SITE-NAME> <UNIX-USER> [HOST]
    HOST is only optional if you are running this on an EC2 instance.
    --default means to install as the default site for this server,
    rather than a virtualhost for HOST.

The `<UNIX-USER>` parameter is the name of the Unix user that you want
to own and run the code.  (This user will be created by the script.)

The `HOST` parameter is a hostname for the server that will be usable
externally -- a virtualhost for this name will be created by the
script, unless you specified the `--default` option..  This parameter
is optional if you are on an EC2 instance, in which case the hostname
of that instance will be used.

For example, if you wish to use a new user called `fms` and the
hostname `fixmystreet.127.0.0.1.xip.io` (xip.io is a very helpful service for
development, allowing easy domain/wildcard domain usage without having to edit
your hosts file), creating a virtualhost just for that hostname, you could
download and run the script with:

    curl -L -O https://github.com/mysociety/commonlib/raw/master/bin/install-site.sh
    sudo sh install-site.sh fixmystreet fms fixmystreet.127.0.0.1.xip.io

Or, if you want to set this up as the default site on an EC2 instance,
you could download the script, make it executable and then invoke it
with:

    sudo ./install-site.sh --default fixmystreet fms

Please be aware that the last part of the installation process,
installing Perl modules, may take a long time to complete.

When the script has finished, you should have a working copy of the
website, accessible via the hostname you supplied to the script.

By default, the admin part of the website (`/admin`) requires a user with
superuser permission to log in. In order to use this
interface, you will need to create a username and password for one or
more superusers.  To add such a user, you can use the `createsuperuser`
command, as follows:

    ubuntu@ip-10-58-66-208:~$ sudo su - fms
    fms@ip-10-58-191-98:~$ cd fixmystreet
    fms@ip-10-58-191-98:~/fixmystreet$ bin/createsuperuser fmsadmin@example.org password
    fmsadmin@example.org is now a superuser.

The script will install postfix to allow outgoing email; you can change the
`SMTP_SMARTHOST` and other `SMTP` variables in `conf/general.yml` to use a
different SMTP server.

Please also see the instructions for [updating your installation](/updating/ami/).

