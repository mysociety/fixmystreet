---
layout: page
title: Vagrant
---

# FixMyStreet using Vagrant

<p class="lead">
Vagrant provides an easy method to set up virtual development environments; for
further information see <a href="http://www.vagrantup.com">the Vagrant website</a>.
We bundle an example Vagrantfile in the repository, which runs the
<a href="{{ site.baseurl }}install/install-script/">install script</a> for you.
</p>

Note that this is just one of [four ways to install FixMyStreet]({{ site.baseurl }}install/).

The included steps will use vagrant to create a development environment where
you can run the test suite, the development server and make changes to the
codebase.

The basic process is to create a base virtual machine, and then provision it
with the software packages and setup needed. There are several ways to do this,
including Chef, Puppet, or the existing FixMyStreet install script which we
will use. The supplied scripts will create you a Vagrant VM based on the server
edition of Ubuntu 12.04 LTS that contains everything you need to work on
FixMyStreet.

1. Clone the repository, `cd` into it and run vagrant. This will provision the
   system and can take some time.

        git clone --recursive https://github.com/mysociety/fixmystreet.git
        cd fixmystreet
        vagrant up --no-color

## Working with the vagrant box

You should now have a local FixMyStreet development server to work with. You
can edit the files locally and the changes will be reflected on the virtual
machine.

To start the dev server:

    vagrant ssh

    # You are now in a terminal on the virtual machine
    cd fixmystreet

    # run the dev server
    bin/cron-wrapper script/fixmystreet_app_server.pl -d -r --fork

The server should now be running and you can visit it at the address
http://fixmystreet.127.0.0.1.xip.io:3000/
