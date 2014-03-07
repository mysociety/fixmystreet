---
layout: default
title: Customising
---

# Customising FixMyStreet

<p class="lead">This document explains how to tailor the default installation
of FixMyStreet to your requirements, including limiting the geographic area it
accepts queries for, translating the text, and changing the look and feel.</p>

## Overview

FixMyStreet implements a "Cobrand" system in order to allow customisation of
the default behavior. As well as configuration options you specify in the
`conf/general.yml` file, a Cobrand is made up of a set of templates, CSS, and an
**optional** Cobrand module that contains Perl code that customises the way the
Cobrand behaves. There are defaults for all of these so the Cobrand only needs
to override things that are specific to it.

Customisations should be implemented like this as this means that any
upgrade to FixMyStreet will not overwrite your unique changes.

It is customary for a cobrand to have the same name as your site,
e.g if your site is www.FixMyPark.com then your Cobrand could be
called FixMyPark. The default Cobrand is called Default.

## Feeding back changes

It would be great if the changes you make to the code could be fed back
upstream to benefit other users. Obviously if you've only customised templates
and CSS you may not feel you have to, but it's likely you'll have needed to
make actual code changes for your particular environment, and feeding these
back means it is easier to update the code from upstream in future to gain new
features and bugfixes.
[More information on feeding back changes](/feeding-back/).

# Areas of customisation

Here is a list of the various aspects of FixMyStreet that you can customise,
please follow the links for more information:

<div class="row-fluid">
  <div class="span6">
    <ul class="nav nav-pills nav-stacked">
      <li><a href="language/">How to change or translate FixMyStreet&rsquo;s language</a></li>
      <li><a href="fms_and_mapit/">How FixMyStreet assigns reports to bodies</a></li>
      <li><a href="geocoder/">How to customise the geocoder</a></li>
      <li><a href="css/">How to change the design</a></li>
      <li><a href="templates/">How to customise templates</a></li>
      <li><a href="send_reports/">How reports are sent by FixMyStreet</a></li>
    </ul>
  </div>
</div>

### Cobrand module

If you need customistation beyond the above pages, you might need to make a
Cobrand module. These are automatically loaded according to the current Cobrand
and can be found in `perllib/FixMyStreet/Cobrand/`. There is a default Cobrand
( `Default.pm` ) which all Cobrands should inherit from. A Cobrand module can
then override any of the methods from the default Cobrand. [More information on
Cobrand modules](/customising/cobrand-module/).

