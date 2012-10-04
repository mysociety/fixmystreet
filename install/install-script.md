---
layout: default
title: Install script
---

# FixMyStreet Install Script

If you have a new installation of Debian squeeze or Ubuntu precise,
you can use an install script to set up a basic installation of
FixMyStreet on your server.

*Warning: only use this script on a newly installed server - it will
make significant changes to your server's setup, including modifying
your nginx setup, creating a user account, creating a database,
installing new packages etc.*

The script to run is called [`install-site.sh`, in our `commonlib` repository](https://raw.github.com/mysociety/commonlib/master/bin/install-site.sh).
That script's usage is as follows:

    Usage: ./install-site.sh [--default] <SITE-NAME> <UNIX-USER> [HOST]
    HOST is only optional if you are running this on an EC2 instance.
    --default means to install as the default site for this server,
    rather than a virtualhost for HOST.

The `<UNIX-USER>` parameter is the name of the Unix user that you want
to own and run the code.  (This user will be created by the script.)

The `HOST` parameter is a hostname for the server that will be usable
externally - a virtualhost for this name will be created by the
script, unless you specified the `--default` option..  This parameter
is optional if you are on an EC2 instance, in which case the hostname
of that instance will be used.

For example, if you wish to use a new user called `fms` and the
hostname `fms.example.org`, creating a virtualhost just for that
hostname, you could download and run the script with:

    curl https://raw.github.com/mysociety/commonlib/master/bin/install-site.sh | \
        sudo sh -s fixmystreet fms fms.example.org

Or, if you want to set this up as the default site on an EC2 instance,
you could download the script and then invoke it with:

    sudo ./install-site.sh --default fixmystreet fms

Please be aware that the last part of the installation process,
installing Perl modules, may take a long time to complete.

When the script has finished, you should have a working copy of the
website, accessible via the hostname you supplied to the script.

By default, the admin part of the website (`/admin`) is password
protected (with HTTP basic authentication).  In order to use this
interface, you will need to create a username and password for one or
more admin users.  To add such a user, you can use the `htpasswd`
command from the `apache2-utils` packages, as follows:

    ubuntu@ip-10-58-66-208:~$ sudo apt-get install apache2-utils
    [...]
    ubuntu@ip-10-58-66-208:~$ sudo su - fms
    fms@ip-10-58-191-98:~$ htpasswd /var/www/fixmystreet/admin-htpasswd fmsadmin
    New password:
    Re-type new password:
    Adding password for user fmsadmin

You should then make sure that your local MTA is correctly configured
to allow the `fms` user to send email, or change the `SMTP_SMARTHOST`
variable in `conf/general.yml` to use a different smarthost.
