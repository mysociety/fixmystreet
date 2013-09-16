# Using Vagrant

Vagrant provides an easy method to setup virtual development environments, for
further information see [their website](http://www.vagrantup.com).

The included steps will use vagrant to create a dev environment where you can
run the test suite, the development server and of course make changes to the
codebase.

The basic process is to create a "base" vm, and then "provision" it with the
software packages and setup needed. There are several ways to do this, including
Chef, Puppet, or the existing FixMyStreet install script which we will use. The
supplied scripts will create you a Vagrant VM based on the server edition of
Ubuntu 12.04 LTS that contains everything you need to work on FixMyStreet.

## Pre-requisites

1. Install [VirtualBox](http://www.virtualbox.org/wiki/Downloads)
2. Install [Vagrant](http://downloads.vagrantup.com/)

## Get the FixMyStreet code

Create a folder somewhere that you'll be doing your work from and clone the repo
into it.

``` bash
mkdir FMS-vagrant
cd FMS-vagrant
git clone --recursive https://github.com/mysociety/fixmystreet.git
```

## Set up the Vagrant box

The vagrant configuration needs to be placed in the correct place.

``` bash
# NOTE - you need to be in the 'FMS-vagrant' dir

cp fixmystreet/conf/Vagrantfile.example Vagrantfile

# start the vagrant box. This will provision the system and can take a long time.
vagrant up --no-color
```

## Working with the vagrant box

You should now have a local FixMyStreet development server to work with. You
can edit the files locally and the changes will be reflected on the virtual
machine.

To start the dev server:

``` bash
vagrant ssh

# You are now in a terminal on the virtual machine
cd /vagrant/fixmystreet

# run the dev server
bin/cron-wrapper script/fixmystreet_app_server.pl -d -r --fork
```

The server should now be running and you can visit it at the address
http://127.0.0.1.xip.io:3000/

Enjoy!
