---
layout: page
title: AMI for EC2
---

# FixMyStreet AMI for EC2

<p class="lead">
  To help people to get started with the FixMyStreet platform, we have
  created an AMI (Amazon Machine Image) with a basic installation of
  FixMyStreet, which you can use to create a running server on an Amazon
  EC2 instance.
</p>

Note that this is just one of [many ways to install FixMyStreet]({{ "/install/" | relative_url }}).

## Installing on Amazon's Web Services

If you don't have your own server, or simply prefer to use an external one, you
can use Amazon Web Services (AWS) instead. They provide difference scale
servers, called instances. The smallest instance, the Micro, will be [free
for a year](http://aws.amazon.com/free/).

### Using our pre-built AMI

The AMI we've prepared for you can be found in the **EU West (Ireland)**
region, with the ID `ami-05386aa7b2b4faee9` and name "FixMyStreet installation
full 2018-12-21". You can launch an instance based on that AMI with
[this link](https://console.aws.amazon.com/ec2/home?region=eu-west-1#launchAmi=ami-05386aa7b2b4faee9).
 This AMI is based on the [latest tagged release](https://github.com/mysociety/fixmystreet/releases)
 and contains everything you need to get a base install up and running.

When you create an EC2 instance based on that AMI, make sure that you
choose Security Groups that allow at least inbound HTTP, HTTPS and
SSH, and perhaps SMTP as well for email.

When your EC2 instance is launched, you will be able to log in as the
`admin` user.  This user can `sudo` freely to run commands as root.
However, the code is actually owned by (and runs as) the `fms` user.
After creating the instance, you may want to edit a configuration
file to set a couple of parameters.  That configuration file is
`/home/fms/fixmystreet/conf/general.yml`, which can be edited with:

    admin@ip-10-58-191-98:~$ sudo su - fms
    fms@ip-10-58-191-98:~$ cd fixmystreet
    fms@ip-10-58-191-98:~/fixmystreet$ nano conf/general.yml

You should set
<code><a href="{{ "/customising/config/#contact_email" | relative_url }}">CONTACT_EMAIL</a></code>
and
<code><a href="{{ "/customising/config/#do_not_reply_email" | relative_url }}">DO_NOT_REPLY_EMAIL</a></code>
or whatever you wish to use. postfix is installed so that outgoing email will
work, but this may need further configuration.

Then you should restart the Catalyst FastCGI server with:

    fms@ip-10-58-191-98:~/fixmystreet$ logout
    admin@ip-10-58-191-98:~$ sudo service fixmystreet restart

If you find the hostname of your EC2 instance from the AWS console,
you should then be able to see the site at http://your-ec2-hostname.eu-west-1.compute.amazonaws.com

By default, the admin part of the website (`/admin`) requires a user with
superuser permission to log in. In order to use this
interface, you will need to create a username and password for one or
more superusers.  To add such a user, you can use the `createsuperuser`
command, as follows:

    admin@ip-10-58-66-208:~$ sudo su - fms
    fms@ip-10-58-191-98:~$ cd fixmystreet
    fms@ip-10-58-191-98:~/fixmystreet$ bin/createsuperuser fmsadmin@example.org password
    fmsadmin@example.org is now a superuser.

This basic installation uses the default cobrand, with a
(deliberately) rather garish colour scheme.  

### Building your own AMI

You may have specific requirements that mean you want to create your own
customised AMI so we provide access to the Packer configuration files we
use to generate our images in our [Public Builds repository](https://github.com/mysociety/public-builds)
together with some guidance on how you can customise the build process.

#### Integrating with other AWS services

One option that we get asked about is how to integrate the AMI with other services
within AWS such as RDS. This is more challenging as we can't know about each
potential environment, but the Public Builds repository contains a recipe that can
be used to create a slim version of the AMI that omits the Postgres database
and memcache instance, similar in some respects to [the Docker build we provide](/install/docker/).

In order to use this effectively you will need to provide a Postgres database
with the FixMyStreet schema loaded and a memcached endpoint, perhaps using RDS
and Elasticache. You would then need to build a custom slim AMI and seed the
relevant configuration files.

See the [FixMyStreet specific notes](https://github.com/mysociety/public-builds/blob/master/docs/fixmystreet.md)
in the Pubic Builds repository for more information.

## Installation complete... now customise

You should then proceed
to [customise your installation](/customising/).

Please also see the instructions for [updating your installation](/updating/ami/).
