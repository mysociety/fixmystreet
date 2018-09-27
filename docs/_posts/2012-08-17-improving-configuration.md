---
layout: post
title: Improving Configuration
author: matthew
---

Now that a default install is a bit more straightforward to set up, our
thoughts turn to improving the customistation of that default install.
Currently, apart from the options already present in the main configuration
file, that involves knowing a bit of Perl, in order to create a Cobrand .pm
file containing the various customistations. So to reduce that dependency,
we've moved a number of these options into the main configuration file, so that
hopefully a standard customisation might not need a Cobrand .pm file at all.

These changes range from simple text strings that are now in templates, through
to specifying what areas from MapIt you are interested in, or what languages
the site is available in. The general.yml-example file contains information on
each option, and we've updated our [customisation documentation](/customising/)
as well.

Also, thanks to some testing of a current installation by
[Anders](https://github.com/kagee) for FiksGataMi, we've made more incremental
improvements to the installation, including fixing a couple of tests that
shouldn't run unless your configuration is set up in a particular way, making
sure inherited cobrands use the best templates, and including the
Catalyst::Devel module so running the development server is easier.

