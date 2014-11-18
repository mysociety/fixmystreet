---
layout: post
title: Easy Installation
author: matthew
---

Four months ago, someone raised [a
ticket](https://github.com/mysociety/fixmystreet/issues/302) on FixMyStreet's
GitHub account, asking for alternative ways of setting up an installation.
We certainly agreed this was a good idea, as we're well aware that there
are various different parts to FixMyStreet that might require quite a bit of
knowledge in setting up.

We're now pleased to announce that we have created an [AMI](/install/ami/)
(Amazon Machine Image) containing an already set-up default installation of
FixMyStreet. You can use this to create a running server on an Amazon EC2
instance. If you haven't used Amazon Web Services before, then you can get a
Micro instance free for a year.

If you have your own server, then we have separately released the [install
script](/install/install-script/) that is used to create the AMI, which can be
run on any clean Debian or Ubuntu server to set everything up for you, from
the PostgreSQL database to nginx.

If you prefer to do things manually, and already know how to set up your
database and web server, our [manual documentation](/install/) is still
available.

An AMI and install script is also available for MapIt -- see our
[MapIt documentation](http://mapit.poplus.org/) for more details.
This should make it very straightforward to get something set up for testing
and development.

Do let us know how you get on.
