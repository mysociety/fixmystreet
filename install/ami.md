---
layout: default
title: AMI for EC2
---

# FixMyStreet AMI for EC2

To help people to get started with the FixMyStreet platform, we have
created an AMI (Amazon Machine Image) with a basic installation of
FixMyStreet, which you can use to create a running server on an Amazon
EC2 instance.

If you haven't used Amazon Web Services before, then you can get a
Micro instance which will be [free for a
year](http://aws.amazon.com/free/).

The AMI can be found in the **EU West (Ireland)** region, with the ID
`ami-b7a7a6c3` and name "Basic FixMyStreet installation 2012-10-02".

When you create an EC2 instance based on that AMI, make sure that you
choose Security Groups that allows at least inbound HTTP, HTTPS and
SSH.

When your EC2 instance is launched, you will be able to log in as the
`ubuntu` user.  This user can `sudo` freely to run commands as root.
However, the code is actually owned by (and runs as) the `fms` user.
After creating the instance, you may want to edit a configuration
file to set a couple of parameters.  That configuration file is
`/home/fms/fixmystreet/conf/general.yml`, which can be edited with:

    ubuntu@ip-10-58-191-98:~$ sudo su - fms
    fms@ip-10-58-191-98:~$ cd fixmystreet
    fms@ip-10-58-191-98:~/fixmystreet$ nano conf/general.yml

You should set `EMAIL_CONTACT` to your email address.  For outgoing
email to work, you will either need to set the `SMTP_SMARTHOST`
variable in the same file, or configure an MTA on the server so that
the default (`localhost`) will work.

Then you should restart the Catalyst FastCGI server with:

    fms@ip-10-58-191-98:~/fixmystreet$ logout
    ubuntu@ip-10-58-191-98:~$ sudo /etc/init.d/fms-catalyst-fastcgi restart

If you find the hostname of your EC2 instance from the AWS console,
you should then be able to see the site at http://your-ec2-hostname.eu-west-1.compute.amazonaws.com

This basic installation uses the default cobrand, with a
(deliberately) rather garish colour scheme.  You should then proceed
to [customise your installation](/customising/).
