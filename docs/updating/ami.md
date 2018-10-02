---
layout: page
title: Updating an AMI installation
---

# Updating an AMI installation

<p class="lead">Let's say you set up an EC2 instance from our AMI when FixMyStreet was on
version 2.0, and you now want to upgrade to version 2.1. This page should
help.</p>

(If you forked the code on GitHub and cloned it yourself, you probably want to see our
main [update help](/updating/).)

**Note:** Up to and including version 2.4 we based our AMI on Ubuntu. From version 2.4.1
the AMI is based on Debian. This shouldn't affect the process below; the main
difference is that in AMIs created before the release of version 2.4.1 the user
account will be `ubuntu` while for those created since the user account will be
`admin`, so be careful to check which applies in your case.

Firstly, log in to your EC2 instance as the relevant user, as you did when
setting up the instance. You should become the fms user and switch to the right
directory:

    admin@ip-10-58-191-98:~$ sudo su - fms
    fms@ip-10-58-191-98:~$ cd fixmystreet
    fms@ip-10-58-191-98:~/fixmystreet$

To fetch new upstream code, but not yet use it, use:

    fms@ip-10-58-191-98:~/fixmystreet$ git fetch origin

Then merging the new version of the upstream code into your version will bring
your code up-to-date.  You can do that with:

    fms@ip-10-58-191-98:~/fixmystreet$ git merge v2.1

If you have made alterations to your local repository, then you will need to
make sure they are all committed to your local branch and fork first, see
[setting up a fork](/feeding-back/) for more information. You may want
to try checking out your repository elsewhere and trying the merge there first,
to see if it there are any problems.

After updating the code, you should run the following command to update any
needed dependencies and any schema changes to your database. It's a good idea
to take a backup of your database first.

    fms@ip-10-58-191-98:~/fixmystreet$ script/update

If you have made changes to the schema yourself, this may not work,
please feel free to [contact us](/community/) to discuss it first.

Lastly, you should restart the Catalyst FastCGI server with:

    fms@ip-10-58-191-98:~/fixmystreet$ logout
    admin@ip-10-58-191-98:~$ sudo service fixmystreet restart
