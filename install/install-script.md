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
your Apache setup, creating a user account, creating a database,
installing new packages etc.*

The script to run is `pre-install-as-root`, which takes two parameters:

1. The name of the Unix user that you want to own and run the code.
   (This user will be created by the script.)

2. A hostname for the server that will be usable externally - an
   Apache virtualhost for this name will be created by the script.

For example, if you wish to use a new user called `fms` and the
hostname `fms.example.org`, you would run the script with:

    curl https://raw.github.com/mysociety/fixmystreet/master/bin/pre-install-as-root | \
        sudo sh -s fms fms.example.org

Please be aware that the last part of the installation process,
installing Perl modules, may take a long time to complete.

When the script has finished, you should have a working copy of the
website, accessible via the hostname you supplied to the script.

You should then make sure that your local MTA is correctly configured
to allow the `fms` user to send email, or change the `SMTP_SMARTHOST`
variable in `conf/general.yml` to use a different smarthost.
