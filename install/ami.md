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
`ami-73cacb07` and name "Basic FixMyStreet installation".

When you create an EC2 instance based on that AMI, make sure that you
choose Security Groups that allows at least inbound HTTP, HTTPS and
SSH.

When your EC2 instance is launched, you will be able to log in as the
`ubuntu` user.  This user can `sudo` freely to run commands as root.
However, the code is actually owned by (and runs as) the `fms` user.
After creating the instance, you will need edit one configuration file
to set a couple of parameters in the file
`/home/fms/fixmystreet/conf/general.yml`.  You can edit the file with:

    ubuntu@ip-10-58-191-98:~$ sudo su - fms
    fms@ip-10-58-191-98:~$ cd fixmystreet
    fms@ip-10-58-191-98:~/fixmystreet$ nano conf/general.yml

You need to change the variable `BASE_URL` to the externally visible
URL for this EC2 instance.  For example, if its hostname were
`ec2-46-137-142-196.eu-west-1.compute.amazonaws.com`, you would set
`BASE_URL` as follows:

    BASE_URL: 'http://ec2-46-137-142-196.eu-west-1.compute.amazonaws.com'

You should also set the `EMAIL_DOMAIN` variable:

    EMAIL_DOMAIN: 'ec2-46-137-142-196.eu-west-1.compute.amazonaws.com'

For outgoing email to work, you will either need to set the
`SMTP_SMARTHOST` variable in the same file, or configure an MTA on the
server so that the default (`localhost`) will work.

And then restart Apache:

    fms@ip-10-58-191-98:~/fixmystreet$ logout
    ubuntu@ip-10-58-191-98:~$ sudo /etc/init.d/apache2 restart
     * Restarting web server apache2
     ... waiting                                                 [ OK ]

Then you should be able to visit your instance of FixMyStreet at the
URL you set as `BASE_URL`.

This basic installation uses the default cobrand, with a
(deliberately) rather garish colour scheme.  You should then proceed
to [customise your installation](/customising/).
