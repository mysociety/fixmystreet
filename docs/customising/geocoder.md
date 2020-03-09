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

If you're running a site in the UK and want junction lookup (e.g. "M5 junction
11a") then see the [Junction lookup](#junction-lookup) section below.

## Detailed flow: location &rarr; map pin &rarr; drop-down menu

![FMS bodies and contacts](/assets/img/fms_bodies_and_contacts.png)

## Junction lookup

If the site is going to be run in the UK and you'd like the ability to do
junction lookups, i.e. allow the user to search for "M60, Junction 2" and have
it geocode to the correct location, then you'll need to generate a junctions
database.

{% highlight bash %}
$ mkdir ../data
$ wget https://www.whatdotheyknow.com/request/272238/response/675823/attach/2/Gazetteer%20All%20Mposts%20only.zip
$ unzip Gazetteer\ All\ Mposts\ only.zip
$ in2csv Gazetteer_All_Mposts_only.xlsx > markerposts.csv
$ bin/make-junctions-database markerposts.csv
{% endhighlight %}

This will create a SQLite database at `../data/roads.sqlite`. If this is present
then it will be used by the postcode search to do a junction lookup.
