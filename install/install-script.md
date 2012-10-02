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

The script to run is `pre-install-as-root`, whose usage is as follows:

    Usage: ./pre-install-as-root [--default] <UNIX-USER> [HOST]
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

    curl https://raw.github.com/mysociety/fixmystreet/master/bin/pre-install-as-root | \
        sudo sh -s fms fms.example.org

Or, if you want to set this up as the default site on an EC2 instance,
you could download the script and then invoke it with:

    sudo pre-install-as-root --default fms

Please be aware that the last part of the installation process,
installing Perl modules, may take a long time to complete.

When the script has finished, you should have a working copy of the
website, accessible via the hostname you supplied to the script.

You should then make sure that your local MTA is correctly configured
to allow the `fms` user to send email, or change the `SMTP_SMARTHOST`
variable in `conf/general.yml` to use a different smarthost.
