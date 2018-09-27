---
layout: page
title: How FixMyStreet assigns reports to bodies
author: dave
---

# How FixMyStreet assigns reports to bodies

<p class="lead">
  When you add a <a href="{{ "/glossary/#body" | relative_url }}" class="glossary__link">body</a>
  to FixMyStreet, you specify which <a href="{{ "/glossary/#area" | relative_url }}" class="glossary__link">areas</a>
  it covers. The areas are typically defined by administrative boundaries: these
  are <em>not</em> part of FixMyStreet, but are made available through our
  service called <a href="{{ "/glossary/#mapit" | relative_url }}" class="glossary__link">MapIt</a>.
</p>

Note that MapIt tells FixMyStreet what administrative boundaries a point lies
within: it does not actually draw the maps (by default, FixMyStreet uses
<a href="{{ "/glossary/#osm" | relative_url }}" class="glossary__link">OpenStreetMap</a> for that).

## How this works

When someone places a pin on the FixMyStreet
<a href="{{ "/glossary/#map" | relative_url }}" class="glossary__link">map</a>
to report a problem, FixMyStreet sends the 
<a href="{{ "/glossary/#latlong" | relative_url }}" class="glossary__link">lat-long</a>
coordinates of that position to MapIt. MapIt responds with a list of the areas
that the pin lies within. FixMyStreet then looks in its own database to find
all the bodies that cover that area, and the
<a href="{{ "/glossary/#contact" | relative_url }}" class="glossary__link">contacts</a>
(which are usually email addresses) that you have added for each of
those bodies. Because each contact is associated with a
<a href="{{ "/glossary/#category" | relative_url }}" class="glossary__link">category</a>
of problem (for example, "Potholes" or "Graffiti"), FixMyStreet can build a
list of all the problem categories that *can* be reported at this location. In
fact, this list appears as the drop-down menu ("Pick a category") on the
report-a-problem page.

This means that your FixMyStreet installation must be able to connect to a
MapIt service which knows about the administrative boundaries in your part of the
world. [See below](#boundaries) for more about setting this up.

## Detailed flow: location &rarr; map pin &rarr; drop-down menu

![FMS bodies and contacts]({{ "/assets/img/fms_bodies_and_contacts.png" | relative_url }})

<a name="boundaries"> </a>

## How to set up the area boundaries

The type of boundary data you need depends on a number of factors, but will
probably be one of these:

   * ["Everywhere"]({{ "/customising/boundaries/#everywhere" | relative_url }}) -- you can run FixMyStreet without a specific boundary
   * [Simple approximate area]({{ "/customising/boundaries/#approx-area" | relative_url }}) -- that is, just one area around the place you need
   * [Simple approximate areas]({{ "/customising/boundaries/#approx-areas" | relative_url }}) -- as above, but for multiple areas
   * [Accurate OpenStreetMap data]({{ "/customising/boundaries/#mysociety-mapit" | relative_url }}) -- the preferred option
   * [Accurate data that isn't on OSM]({{ "/customising/boundaries/#accurate" | relative_url }}) -- if you have your own boundary data, for example

If you're not sure which is for you, read through the 
[whole page about admin boundaries]({{ "/customising/boundaries/" | relative_url }}).


