---
layout: post
title: Default Workings
author: matthew
---

In the past few weeks, a number of improvements have been made to the
FixMyStreet default set up, so that installation should provide you with a
working setup more easily and quickly, before you get on and make all the
necessary customisations you will want to for the service you are setting up.

Firstly, we've tidied and consolidated the documentation on to this site,
putting everything you need in one place. We are using GitHub pages, which means
that the documentation is bundled along with the repository when checking out,
which might be useful. The installation guide now includes help for installing
on Mac OS X, and various other tweaks and improvements.

Next, the codebase now automatically defaults to
[OpenStreetMap](http://www.openstreetmap.org/) maps and geocoding &ndash; these are
available, with more or less data, everywhere in the world, so you should be
able to test your installation and see working maps.

Whilst an installation of [MapIt](http://global.mapit.mysociety.org/) may be
necessary for your FixMyStreet to work as you want &ndash; mapping locations picked to
the right authority might need some private boundary data, for example &ndash; the
code will now default to work as if everywhere is one administrative area.

The code for sending reports has been refactored and modularised, enabling
proprietary options to be more easily added alongside the standard email,
Open311, and so on.

We have removed any UK specific code from the default cobrand, moving it to
a UK cobrand (which is then in turn inherited by the various council cobrands
we have made in the UK). This should mean that you find you have less to override,
and more things should work by default.

![Default screenshot](/assets/img/2012-07-27-screenshot.png)

Lastly, the default cobrand now uses the new style that you can see on
<https://www.fixmystreet.com>. By default, we have picked a pretty yet garish
colour scheme, in order to remind you that you almost certainly want to change
the colours being used for your own installation :)

