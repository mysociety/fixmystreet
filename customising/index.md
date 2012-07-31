---
layout: default
title: Customising
---

# Customising FixMyStreet

This document explains how to tailor the default installation of
FixMyStreet to your requirements, including limiting the geographic
area it accepts queries for, translating the text, and changing the look and feel.

## Overview

FixMyStreet implements a "Cobrand" system in order to allow customisation
of the default behavior. The Cobrand is made up of a set of templates for
the Cobrand and a Cobrand module that contains code that customises the
way the Cobrand behaves. There are defaults for both of these so the
Cobrand only needs to override things that are specific to it.

Customisations should be implemented like this as this means that any
upgrade to FixMyStreet will not overwrite your changes.

It is customary for a cobrand to have the same name as your site,
e.g if your site is www.FixMyPark.com then your Cobrand could be
called FixMyPark.

The default Cobrand is called Default.

## Templates

Templates are found in the templates directory. Within that there are
seperate directories for web templates and email templates. Under each
of these there is a directory for each Cobrand. In our FixMyPark example
this would be `templates/web/fixmypark` for the web templates and
`templates/email/fixmypark` for the email templates.

The full set of templates is stored in the default Cobrand and if no
equivalent template is found in a Cobrand directory FixMyStreet will
use the default template.

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

## Cobrand modules

Much of the rest of the customisation takes place in the Cobrand modules. These
are automatically loaded according to the current Cobrand and can be found in
`perllib/FixMyStreet/Cobrands/`. There is a default Cobrand ( Default.pm ) which
all Cobrands should inherit from. A Cobrand module can then override any of the
methods from the default Cobrand.

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

Many of the functions in the Cobrand module are used by FixMyStreet in the UK
to allow the site to offer versions localised to a single authority and should
not be needed for most installs. Listed below are the most useful options that
can be changed:

* site_title

    This should be set to the name of your site.

* item country

    This should be set to the two letter ISO code for the country your site is for.

* disambiguate_location

    This is used by the Geocoding module of FixMyStreet to constrain the area for
which results are returned when locating an address. It should return a hash
reference of parameters that are compatible with the arguments of the geocoding module
you are using.

    At a most basic level it should limit it to the country you are in:

        sub disambiguate_location {
            return {
                country => 'uk',
            };
        }

    You can limit it to a smaller area using bounding boxes to contrain the area
that the geocoder will consider:

        sub disambiguate_location {
            return {
                centre => '52.688198,-1.804966',
                span   => '0.1196,0.218675',
                bounds => [ 52.807793, -1.586291, 52.584891, -1.963232 ],
            };
        }

    The centre and span are used by the Google geocoding API and the bounds by
Bing. Note that these arguments are only as good a limiting results as the API
that they are used by.

* geocode_postcode

    This function is used to convert postcodes (zip codes, etc.) entered into a
latitude and longitude, if there's a different way from your geocoder of doing so
(e.g. a MapIt install). If the text passed is not a valid postcode then an
error should be returned. If you do not want to use postcodes, just do not define
this function.

    If the postcode is valid and can be converted then the return value should
look like this:

        return { latitude => $latitude, longitude => $longitude };

    If there is an error it should look like this:

        return { error => $error_message };

* find_closest and find_closest_address_for_rss

    These are used to provide information on the closest street to the point of
the address in reports and RSS feeds or alerts.

* allow_photo_upload

    Return 0 to disable the photo upload field.

* allow_photo_display

    Return 0 to disable the display of uploaded photos.

* area_types

    If you are using MapIt alongside FixMyStreet this should return a
list of the area type codes that the site will handle. This is used
to filter the data returned from MapIt so that only appropriate areas are
displayed.

* remove_redundant_councils

    This is used to filter out any overlapping jurisdictions from MapIt results
where only one of the authorities actually has reponsability for the events
reported by the site. An example would be be a report in a city where MapIt
has an ID for the city council and the state council (and they are both the
same MapIt area type) but problems are only reported to the state. In this case
you would remove the ID for the city council from the results.

* short_name

    This is used to turn the full authority name returned by MapIt into a short
name.

## Translations and Language

The translations for FixMyStreet are stored as gettext files and the
language for a Cobrand is set in the `set_lang_and_domain` call of
the Cobrand module.

The templates use the `loc` function to pass strings to gettext for
translation. The `commonlib/bin/gettext-makemo` script may be useful
for compiling the .po files for use with Apache.
