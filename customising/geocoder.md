---
layout: page
title: How to customise the geocoder
author: matthew
---

# How to customise the FixMyStreet geocoder

<p class="lead">
  The first step of using FixMyStreet is entering a string
  that the needs to be <em>geocoded</em> to take you to a relevant map page.
</p>

See the diagram below for the full flow of using FixMyStreet. The geocoder is
near the start of the process, before maps, MapIt boundaries or bodies enter
the picture.

The geocoder takes a string -- for example, the name of a place or a street --
and converts it into a [lat-long]({{ "/glossary/#latlong" | relative_url }}) location.

The geocoder defaults to OpenStreetMap's [Nominatim](http://nominatim.openstreetmap.org).
FixMyStreet also contains Bing and Google based geocoders, and can use
custom geocoders too.

You can customise the geocoding by providing limiting parameters in
<code><a href="{{ "/customising/config/#geocoding_disambiguation" | relative_url }}">GEOCODING_DISAMBIGUATION</a></code>.
You typically need to do this so the geocoder only considers places in the area
your FixMyStreet site is serving. For example, you may want to limit results to
a specific country or city.

The options vary [depending on which geocoder you use]({{ "/customising/config/#geocoding_disambiguation" | relative_url }}).

## Detailed flow: location &rarr; map pin &rarr; drop-down menu

![FMS bodies and contacts](/assets/img/fms_bodies_and_contacts.png)
