---
layout: page
title: Customising
---

# Customising FixMyStreet

<p class="lead">This document explains how to tailor the default installation
of FixMyStreet to your requirements, including limiting the geographic area it
accepts queries for, translating the text, and changing the look and feel.</p>

<div class="row-fluid">
  <div class="span6">
    <ul class="nav nav-pills nav-stacked">
      <li><a href="#overview">Customising FixMyStreet: main issues</a></li>
      <li><a href="fms_and_mapit">How FixMyStreet uses MapIt</a></li>
      <li><a href="send_reports">How FixMyStreet sends reports</a></li>
      <li><a href="/feeding-back">About feeding back your changes</a></li>
    </ul>
  </div>
</div>

<a name="overview">&nbsp;</a>

# Customising FixMyStreet: main issues

## Overview

FixMyStreet implements a "Cobrand" system in order to allow customisation of
the default behavior. As well as configuration options you specify in the
`conf/general.yml` file, a Cobrand is made up of a set of templates and an
optional Cobrand module that contains Perl code that customises the way the
Cobrand behaves. There are defaults for all of these so the Cobrand only needs
to override things that are specific to it.

Customisations should be implemented like this as this means that any
upgrade to FixMyStreet will not overwrite your changes.

It is customary for a cobrand to have the same name as your site,
e.g if your site is www.FixMyPark.com then your Cobrand could be
called FixMyPark.

The default Cobrand is called Default.

## Feeding back changes

It would be great if the changes you make to the code could be fed back
upstream to benefit other users. Obviously if you've only customised templates
and CSS you may not feel you have to, but it's likely you'll have needed to
make actual code changes for your particular environment, and feeding these
back means it is easier to update the code from upstream in future to gain new
features and bugfixes.
[More information on feeding back changes](/feeding-back/).

## Administrative area mapping

FixMyStreet works by mapping points to administrative areas to which reports
can be sent. It normally does this using a different mySociety service called
MapIt. By default, in the absence of a MapIt installation, FixMyStreet will map
any point to the same administrative area, to allow for ease of set up and
testing (and if you only need reports to be sent to one place, this might be
enough!).

Alternatively you can use our MapIt severs (with UK or global data), or set up
one of your own.

See [how FixMyStreet uses MapIt](fms_and_mapit) for a full explanation of how
to get this working.

## Templates

Templates are found in the templates directory. Within that there are
seperate directories for web templates and email templates. Under each
of these there is a directory for each Cobrand. In our FixMyPark example
this would be `templates/web/fixmypark` for the web templates and
`templates/email/fixmypark` for the email templates.

The full set of templates is stored in the default Cobrand and if no equivalent
template is found in a Cobrand directory FixMyStreet will use the default
template. Only make template files for those things you need to do differently,
you do not need to copy all the files into your own templates folder.

By default, the Default cobrand uses the templates in
`templates/web/fixmystreet` that are used for the www.fixmystreet.com website.
If you want to base your design off this, you can inherit from those templates,
rather than the "bare bones" default ones.

At a bare minimum you will probably want to copy the header and footer
web templates found in `templates/web/fixmystreet/header.html` and
`templates/web/fixmystreet/footer.html` into your Cobrand and make appropriate
changes.

The other template you should make your own version of is the FAQ which
is in `templates/web/fixmystreet/faq/faq-en-gb.html`.

## Translations and Language

The translations for FixMyStreet are stored as standard gettext files, in
`FixMyStreet.po` files under `locale/<lang>/LC_MESSAGES/`. Set the `LANGUAGES`
configuration option to the languages your site uses. <small>(Details: the language
for a Cobrand is set in the `set_lang_and_domain` call, but in most cases you
won't need that.)</small>

The templates use the `loc` function to pass strings to gettext for
translation. If you create or update a .po file, you will need to run the
`commonlib/bin/gettext-makemo` script to compile these files into the machine
readable format used by the site.

If you use a new language, you must make sure that the locale for that language
is installed on the server in order for the translations to work properly.
On Debian, you can alter `/etc/locale.gen` and run `sudo locale-gen`.
On Ubuntu, you can just run `sudo locale-gen <LOCALE_NAME>`.

## CSS

The CSS is stored in `web/cobrands/` under which there are directories for Cobrands.
The loading of the CSS is controlled by the header template, as you would expect. Note that
FixMyStreet uses SCSS and Compass to generate its CSS so there are no CSS files
until `bin/make_css` has been run.

The CSS provided with FixMyStreet uses CSS3 media queries in a mobile first
format order to adapt the layout to work on different devices.

The CSS is structured into main files:

* base.css
This contains all the styling for the content of the pages in a mobile sized browser.
* layout.css
This contains all the styling for the content of the pages in a desktop sized browser.
* \_colours.css
This contains basic colour information, so you can easily make a site that
looks different simply by copying these files to your own cobrand CSS
directory, and changing the colours.
* config.rb
This is the config script used by compass; to base your CSS off of FixMyStreet,
you can just copy the one from `web/cobrands/fixmystreet/`.

Our `.gitignore` file assumes that any CSS files directly in a `cobrands/*`
directory are generated from SCSS - if you have CSS files that you want to use
directly, put them in a `css` directory within your cobrand directory.

## Configuration options

Most standard customisation can be carried by setting options in the
`conf/general.yml` file. The example file explains each option, and how it
should be used. Some more information is also given below.

### ALLOWED_COBRANDS

FixMyStreet uses the hostname of the current request along with the contents
of the `ALLOWED_COBRANDS` config option to determine which cobrand to use.
`ALLOWED_COBRANDS` is a list of cobrand names with an optional hostname match.
override. If there is no hostname override then the first cobrand name that
matches all or part of the hostname of the current request is used. If there is
a hostname override then that is compared against the hostname of the current
request. For example if `ALLOWED_COBRANDS` is

    ALLOWED_COBRANDS:
        - fixmypark_blue: 'blue.fixmypark'
        - fixmypark

then a request to www.fixmypark.com will use the fixmypark cobrand but a
request to blue.fixmypark.com will use fixmypark_blue. If no Cobrand listed in
`ALLOWED_COBRANDS` matches then the default Cobrand will be used.

This means you can provide multiple Cobrands for the site if you require, e.g.
for providing different designs, and FixMyStreet will use the first match
listed in `ALLOWED_COBRANDS`.

### LANGUAGES

This is an array of strings specifying what language or languages your
installation uses. For example, if your site is available in English, French,
and German, you would have:

    LANGUAGES:
        - 'en-gb,English,en_GB'
        - 'fr,French,fr_FR'
        - 'de,German,de_DE'

This would then set up things appropriately to use the relevant language files
you have made. Always keep the en-gb line, as some things need that to work
properly.

By default, FixMyStreet is set up so visiting a hostname starting with the
two-letter language code will use that language; otherwise it will detect based
upon the browser.

### MAPIT_URL / MAPIT_AREA_TYPES

If you are using a MapIt installation, then as well as specifying its URL in
`MAPIT_URL`, you can specify the types of area that matter to your FixMyStreet
installation in `MAPIT_AREA_TYPES`. For example, if using Global MapIt (using
OpenStreetMap data), then `MAPIT_URL` will be
'http://global.mapit.mysociety.org/' and `MAPIT_TYPES` might be `[ 'O06' ]`.

### GEOCODING_DISAMBIGUATION

You can customise the geocoding by providing limiting parameters in
`GEOCODING_DISAMBIGUATION`. The options vary depending which geocoder you use,
or you can specify all for if you change geocoder. For the default OSM
geocoder, you can use the bounds, country, and town parameters. Bing adds
centre, bing_culture, and bing_country, and with Google you have centre, span,
google_country, and lang. See the `general.yml-example` file for more details.
Note that these arguments are only as good a limiting results as the API that
they are used by.

## Cobrand module

If you need customistation beyond the above, you will need to make a Cobrand
module. These are automatically loaded according to the current Cobrand and can
be found in `perllib/FixMyStreet/Cobrand/`. There is a default Cobrand
( `Default.pm` ) which all Cobrands should inherit from. A Cobrand module can
then override any of the methods from the default Cobrand.
[More information on Cobrand modules](/customising/cobrand-module/).

