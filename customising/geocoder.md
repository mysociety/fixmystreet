---
layout: default
title: How to customise the geocoder
author: matthew
---

# How to customise the FixMyStreet geocoder

<p class="lead">The first step of using FixMyStreet is entering a string
that the needs to be <em>geocoded</em> to take you to a relevant map page.</p>

See the diagram below for the full flow of using FixMyStreet - the
geocoder is near the start of the process, before maps, MapIt or bodies
enter the picture.

The geocoder defaults to OpenStreetMap's Nominatim; FixMyStreet also contains
Bing and Google based geocoders.

You can customise the geocoding by providing limiting parameters in
`GEOCODING_DISAMBIGUATION`. The options vary depending which geocoder you use,
or you can specify all for if you change geocoder. For the default
OpenStreetMap geocoder, you can use the bounds, country, and town parameters.
Bing adds centre, bing_culture, and bing_country, and with Google you have
centre, span, google_country, and lang. See the `general.yml-example` file for
more details. Note that these arguments are only as good at limiting results as
the API that they are used by.

## Detailed flow: location &rarr; map pin &rarr; drop-down menu

![FMS bodies and contacts](/images/fms_bodies_and_contacts.png)
