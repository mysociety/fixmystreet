---
layout: page
title: Admin boundaries
---

# Admin boundaries and FixMyStreet

<p class="lead">
    When you set up FixMyStreet, you usually need to provide <strong>admin boundaries</strong>
    for each of the 
    <a href="{{ site.baseurl }}glossary/#body" class="glossary">bodies</a>
    you'll be sending reports to. If you're lucky, the boundaries might already
    be available. If not, you'll have do make them. This page explains your
    options.
</p>

## Why FixMyStreet needs boundaries

When someone sticks a pin in the map to report a problem, FixMyStreet uses
boundaries to answer the question: _who is responsible for fixing problems
**here**_?

This also means boundaries let FixMyStreet know if the pin has been put
somewhere that is *not* covered by any of the bodies it normally reports
problems to.

<div class="attention-box">
  We've written a separate page about 
  <a href="{{site.baseurl }}customising/fms_and_mapit/">how FixMyStreet uses MapIt</a>,
  which is the service that determines which area any point (pin) is within. It's
  helpful to understand how that works &mdash; because it also explains how
  FixMyStreet determines which categories of problem can be reported at any
  location &mdash; but the rest of this page is about making and using the boundaries that
  FixMyStreet needs.
</div>

FixMyStreet finds all the bodies that are associated with the area (or areas)
that pin is inside -- those are the bodies to whom the report might be sent.
Which body is actually chosen will depend on which category the user selects
when they complete their problem report.

## Boundaries are independent of your maps!

**Boundaries are not really anything to do with maps** &mdash; they exist
independently of the maps you're using (although, of course, both are about
geography). FixMyStreet shows the map *before* the user clicks on it to place
the pin. It doesn't check the boundaries until *after* the pin has been placed.

## Every body must be associated with an area

So if you're setting up FixMyStreet to run in your region, you *must* provide
these boundaries to FixMyStreet. Once you've done this, you can associate the
bodies you'll be sending reports to with these areas. This is easy to do in
the FixMyStreet admin: you simply choose the area (or areas) from a drop-down
list when you create or edit the body.

## Where to get your boundary data from

If the bodies you are going to be sending reports to are local government
departments, it's possible that this data already exists. We use the admin
boundary data from 
<a href="{{ site.baseurl }}glossary/#osm" class="glossary">OpenStreetMap</a>,
and many countries' data is already available. If that's the case for you, then
this is going to be easy! You just have to identify the areas you need, and
tell FixMyStreet to ignore all the others.

But if the boundaries you need are not already in Open Street Map -- maybe
nobody has ever put them in, or maybe your government doesn't publish such data
for people to use, or perhaps the areas your bodies use are not admin
boundaries anyway -- you'll have to create your own.

## The geometry of boundaries

Areas often don't overlap -- because it's common for local government to
arrange its jurisdiction so that each has its own area to cover.

But actually the MapIt service is very flexible, and you can have areas that
overlap, or be entirely separate and never touch, or even contain all or part
of one another. This is because all FixMyStreet really cares about is asking
MapIt "which areas is this pin in?" MapIt may reply with none, one, or many
areas, depending on how your boundaries are arranged.

Note that more than one body can cover the same area (actually it’s quite
common). For example, two national bodies (the Highways Department and the
Water Department) might both have the same national boundary data.

Also, it's possible to associate a body in FixMyStreet with more than
one area from MapIt. For example, a single port authority could be associated
with the ports on three different islands.


## Types of boundaries

The type of boundary data you need depends on a number of factors, but will
probably be one of these:

   * ["Everywhere"](#everywhere) -- you can run FixMyStreet without a specific boundary
   * [Simple approximate area](#approx-area) -- that is, just one area around the place you need
   * [Simple approximate areas](#approx-areas) -- as above, but for multiple areas
   * [Accurate OpenStreetMap data](#mysociety-mapit) -- the preferred option
   * [Accurate data that isn't on OSM](#accurate) -- if you have your own boundary data, for example

If you're not sure which is for you, read through the sections below.

<!-- TODO add diagrams! Did some Isle of Wight ones but I don't like 'em -->

<a name="everywhere"> </a>

### "Everywhere"

This is the simplest boundary: it's infinte, so anywhere the user clicks is
inside the area called "everywhere".

Use this type of boundary if:

   * the bodies you're sending reports to don't depend on the whereabouts of the problem
   * or all the problem reports are always sent to the same, single body
   * you don't mind that FixMyStreet will never reject any problem report because it's too far away

The advantage of using the boundary "Everywhere" is that it's very easy to set
up. The disadvantage is that your FixMyStreet will accept clicks *anywhere* on
the map. This may be acceptable if you are limiting your 
<a href="{{site.baseurl }}/glossary/#geocoder" class="glosssary">geocoder</a>
to a very specific area.

#### How to set this up

This is the default setup of a new FixMyStreet installation (if you used the 
[installation script]({{ site.baseurl}}install/install-script) or the 
[AMI install]({{ site.baseurl}}install/ami)). 

Set 
<code><a href="{{ site.baseurl }}customising/config/#mapit_url">MAPIT_URL</a></code>
to be blank, and set 
<code><a href="{{ site.baseurl }}customising/config/#mapit_area_types">MAPIT_AREA_TYPES</a></code>
to the special value `ZZZ`. FixMyStreet will use a fake MapIt that always
returns "Everywhere" as the only area that contains the point &mdash; for any
location.

Your `conf/general.yml` file should contain this:

    MAPIT_URL: ''
    MAPIT_AREA_TYPES: ['ZZZ']
    MAPIT_ID_WHITELIST: [ ]
 
<a name="approx-area"> </a>
 
### Simple approximate area

Sometimes you just need a boundary to broadly determine if a pin in the map is
too far away from the single area you're receiving reports for.

Use this type of boundary if you:

   * don't need an accurate boundary (for example, _"anything roughly near the town centre is OK"_)
   * do want to prevent problem reports for locations that are not within this area

#### How to set this up

You need to install your own MapIt instance, and add the area to that. The
MapIt admin interface (which uses the Django framework) lets you click-and-draw
a polygon over a map. Alternatively, we run a MapIt server for custom areas
like this, so &mdash; especially if you are just doing this as a probationary
trial, &mdash; we may be able to host this for you (note though that we do
rate-limit calls to MapIt). Either send us KML shape files, or an screenshot of
your map with the boundary drawn on it for us to copy.

In your `conf/general.yml`, you must set 
<code><a href="{{ site.baseurl }}customising/config/#mapit_url">MAPIT_URL</a></code>
to either your MapIt or
our custom one, and set
<code><a href="{{ site.baseurl }}customising/config/#mapit_area_types">MAPIT_AREA_TYPES</a></code>
to the areas you want (the actual values will depend on what that particular
Mapit is returning). You should also set 
<code><a href="{{ site.baseurl }}customising/config/#mapit_id_whitelist">MAPIT_ID_WHITELIST</a></code>
to the ID of the single area you want.

    MAPIT_URL: 'http://mapit.example.com'
    MAPIT_AREA_TYPES: ['CITY']
    MAPIT_ID_WHITELIST: [ 133 ]

<a name="approx-areas"> </a>

### Simple approximate areas

This is the same as the previous example, but shows that you can have multiple
areas. This works best if they don't need to be very accurate &mdash; that is,
no colinear borders.

Use this type of boundary if you:

   * don't need an accurate boundary (e.g. anything roughly in an area is OK)
   * the boundaries don't adjoin, or are very simple (no crinkly edges)
   * do want to prevent problem reports for locations that are not within these areas

#### How to set this up

Same as previous example: either set up your own instance of MapIt, or ask to
have your boundaries added to our custom one. If you want us to host it, we'll
need KML shape files or a graphic showing the boundary clearly shown so we can
copy it. 

Note that now there may be more than one type of area, and you'll need to explicitly
nominate every area you're interested in with
<code><a href="{{ site.baseurl }}customising/config/#mapit_id_whitelist">MAPIT_ID_WHITELIST</a></code> 
(unless you want *all* the areas this MapIt returns for the given type, in
which case you can set it to be empty).


    MAPIT_URL: 'http://mapit.example.com'
    MAPIT_AREA_TYPES: ['CITY', 'COUNTY']
    MAPIT_ID_WHITELIST: [ 133, 145, 12, 80 ]


<a name="mysociety-mapit"> </a>

### Accurate OpenStreetMap data

It's possible that the admin boundaries of local government in your area are
already available in the OpenStreetMap project. If this is the case,
FixMyStreet can automatically use them. **This is the easiest solution if the
data you need is there** because we already run two servers 
([UK MapIt](http://mapit.mysociety.org) and 
[global MapIt](http://global.mapit.mysociety.org))
that makes this data available.

Use this type of boundary if:

   * the boundary data for the areas you need are already on OpenStreetMap

#### How determine if the boundary data is available

Start by finding the <a
href="{{ site.baseurl }}glossary/#latlong" class="glossary">lat-long</a> of
some of the places you want to cover, and look them up on [global
MapIt](http://global.mapit.mysociety.org) (or maybe the
[UK one](http://mapit.mysociety.org)). If you see the "Areas covering this
point" include the admin boundaries you need, you're good to go! For example,
here's the [page for Oslo, in Norway](http://global.mapit.mysociety.org/point/4326/10.75,59.95.html).

Note that our MapIt servers' data may lag a little behind OSM, so if it's not
there, look on the [OpenStreetMap website](http://www.openstreetmap.org) just
in case it's been added since MapIt's last update. If so, let us know, and
we'll pull it in for you.

Here's an example of the steps to follow to find the data you need to use
global MapIt. This example uses Zurich as an example city.

1. Go to [OpenStreetMap's geocoder](http://nominamtim.openstreetmap.org) and
   enter the name of the city, e.g., "Zurich, Switzerland".

2. Check that's found the right place (and, if you want, check the map is how
   you expected). Click on the **details** link just below the name of the top
   hit. The details page lists lots of data, including the centre point
   (lat/long values that will look something like `-34.9059039,-56.1913569`).

3. Go to [global MapIt](http://global.mapit.mysociety.org) and paste those
   lat/long values into the text input.

4. MapIt will show you all the
   [admin boundaries](http://global.mapit.mysociety.org/point/4326/8.55,47.366667.html)
   that contain that point. You're interested in the ones that relate to
   bodies that serve those areas. For example, if a district council fixes the
   potholes in that district. Specifically, you need the **Administrative
   Boundary Levels** (which will look like `O04` or `O05`), which are the
   values for your 
   <code><a href="{{ site.baseurl }}customising/config/#mapit_area_types">MAPIT_AREA_TYPES</a></code>.
   Remember this data is boundary data from OpenStreetMap -- if the boundaries you
   need are not shown, you may have to set up your own (described below). You can
   also click on any of the boundaries listed on MapIt to see the areas they
   actually cover on the map.

5. The individual *area_id*s are also useful, because you put them into the
   <code><a href="{{ site.baseurl }}customising/config/#mapit_id_whitelist">MAPIT_ID_WHITELIST</a></code>.

#### Using our MapIt servers: some restrictions

We run two public MapIt services:
[mapit.mysociety.org](http://mapit.mysociety.org) covers the UK (because
that's where we're based, and it serves our own [UK
FixMySteet](www.fixmystreet.com) site), and
[global.mapit.mysociety.org](http://global.mapit.mysociety.org), which covers
the whole world. The data we use for global MapIt is from
[OpenStreetMap](http://www.openstreetmap.org), so if someone has put
administrative boundary data for your country into OSM, before too long global
MapIt will have it too.

Please get in touch with us if you are expecting to generate a lot of requests
or **if you are using it commercially**. We rate-limit calls to MapIt, so if
your site gets really busy, you should set up your own instance (we can help
you, and the [code is on github](http://github.com/mysociety/mapit)). But when
you're setting your site up to begin with, you can usually get it running using
one of our MapIt servers.


#### How to set this up

In your `conf/general.yml` file, point 
<code><a href="{{ site.baseurl }}customising/config/#mapit_url">MAPIT_URL</a></code>
at the global MapIt server.

Find the areas you need by looking on the [global Mapit
website](http://global.mapit.mysociety.org) or the
[UK one](http://mapit.mysociety.org). You must also nominate the types
of area these are (effectively the *level* of admin boundary it is. On global,
the area types look something like `[ 'O05', 'O06' ]`. (Note those contain
capital letter O followed by digits). To determine what types you need, look
for the codes marked "Administrative Boundary Levels" that MapIt returns -- for
example, here's [global MapIt's data for
Zurich](http://global.mapit.mysociety.org/point/4326/8.55,47.366667.html).


The UK Mapit types are different. For example, for UK FixMyStreet, we use:

    [ 'DIS', 'LBO', 'MTD', 'UTA', 'CTY', 'COI', 'LGD' ]

which covers all the UK council types (for example, `DIS` is district council,
`CTY` is county council). 

Finally, limit your installation to the specific areas you're interested in
(otherwise you'll be getting areas from the whole world). Identify the specific
areas you want to use, and list them explicitly in
<code><a href="{{ site.baseurl }}customising/config/#mapit_id_whitelist">MAPIT_ID_WHITELIST</a>:

    MAPIT_URL: 'http://global.mapit.mysociety.org'
    MAPIT_AREA_TYPES: ['O06','O07']
    MAPIT_ID_WHITELIST: ['12345','345432','978638']


<a name="accurate"> </a>

### Accurate data that isn't on OSM

Use this type of boundary if:

   * you need accurate boundaries because the different bodies that
     solve problems in your region serve specific areas that are geometrically
     complex and/or are precisely adjacent 
   * the boundary data for the areas you need are not already on OpenStreetMap
   * but you do have access to this data from some other source

This means you have to source the data yourself -- either by getting your local
government to release it, or else drawing it yourself. Then you need to import
this data into a MapIt server and use that.

#### How to set this up

Ideally, if you can source the data from your local government (which means
it's definitive), then it's great if you can add it (as admin boundary data) to
the OpenStreetMap project. Our global MapIt will subsequently import it and
your FixMyStreet can then use it as described in the previous example. If
you're going to do that, **the data must be open data** and you should probably
ask about it on the
[OSM import list](http://lists.openstreetmap.org/listinfo/imports) first. Of
course, if you do this, it means anyone else in the world can use it too, if
they want.

But if you can't do that, or the boundary data you have is not definitive, you
can create your own. Use any good GIS software to plot the boundaries
accurately, and then export it as KML shape files. MapIt can import these, so
you can then either run your own MapIt instance, or ask us to add it to our
custom one.


## Can you see the boundaries?

FixMyStreet doesn't normally display the admin areas and boundaries on the maps
(mainly because most users really don't care &mdash; they just want to report
a problem). But it *is* possible, with some customisation, to change this
behaviour. 

If you just want to see what shape a boundary actually is on the map to check
it's covering the area you want, you can see this by going to the MapIt server
it's on, and looking at that area's HTML page. For example, see the [boundary for
Norway](http://global.mapit.mysociety.org/area/363186.html) on the global Mapit server.



