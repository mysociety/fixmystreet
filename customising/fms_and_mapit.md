---
layout: page
title: How FixMyStreet assigns reports to bodies
author: dave
---

# How FixMyStreet assigns reports to bodies

<p class="lead">When you add a <a href="{{ site.baseurl }}glossary/#body" class="glossary">body</a> toFixMyStreet,
you specify which <a href="{{ site.baseurl }}glossary/#area" class="glossary">areas</a> it
covers. The areas are typically defined by administrative boundaries: these
are <em>not</em> part of FixMyStreet, but are made available through our
service called <a href="{{ site.baseurl }}glossary/#mapit" class="glossary">MapIt</a>. </p>

Note that MapIt tells FixMyStreet what administrative boundaries a point lies
within: it does not actually draw the maps (by default, FixMyStreet uses
OpenStreetMap for that).

## How this works

When someone places a pin on the FixMyStreet <a href="{{ site.baseurl }}glossary/#map" class="glossary">map</a> to report a problem,
FixMyStreet sends the <a href="{{ site.baseurl }}glossary/#latlong" class="glossary">lat-long</a> coordinates of that position to MapIt. MapIt
responds with a list of the areas that the pin lies within. FixMyStreet then
looks in its own database to find all the bodies that cover that area, and the
<a href="{{ site.baseurl }}glossary/#contact" class="glossary">contacts</a> (which are usually email addresses) that you have added for each of
those bodies. Because each contact is associated with a <a href="{{ site.baseurl }}glossary/#category" class="glossary">category</a> of problem
(for example, "Potholes" or "Graffiti"), FixMyStreet can build a list of all
the problem categories that *can* be reported at this location. In fact, this
list appears as the drop-down menu ("Pick a category") on the report-a-problem
page.

This means that your FixMyStreet installation must be able to connect to a
MapIt service which knows about the administrative areas in your part of the
world.

## Detailed flow: location &rarr; map pin &rarr; drop-down menu

![FMS bodies and contacts]({{ site.baseurl }}/assets/img/fms_bodies_and_contacts.png)


## How FixMyStreet can use MapIt

The type of boundary data you need depends on a number of factors, but will
probably be one of these:

   * ["Everywhere"]({{ site.baseurl }}customising/boundaries/#everywhere) -- you can run FixMyStreet without a specific boundary
   * [Simple approximate area]({{ site.baseurl }}customising/boundaries/#approx-area) -- that is, just one area around the place you need
   * [Simple approximate areas]({{ site.baseurl }}customising/boundaries/#approx-areas) -- as above, but for multiple areas
   * [Accurate OpenStreetMap data]({{ site.baseurl }}customising/boundaries/#mysociety-mapit) -- the preferred option
   * [Accurate data that isn't on OSM]({{ site.baseurl }}customising/boundaries/#accurate) -- if you have your own boundary data, for example

If you're not sure which is for you, read through the 
[whole page about admin boundaries]({{ site.baseurl }}customising/boundaries/).


