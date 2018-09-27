---
layout: page
title: Admin boundaries
---

# Admin boundaries and FixMyStreet

<p class="lead">
    When you set up FixMyStreet, you usually need to provide <strong>admin boundaries</strong>
    for each of the 
    <a href="{{ "/glossary/#body" | relative_url }}" class="glossary__link">bodies</a>
    you'll be sending reports to. If you're lucky, the boundaries might already
    be available. If not, you'll have to make them. This page explains your
    options.
</p>

## Why FixMyStreet needs boundaries

When someone sticks a pin in the map to report a problem, FixMyStreet uses
boundaries to answer the question: _who is responsible for fixing problems
**here**_?

This also means that boundaries can be used to determine if the pin has
been put somewhere that is *not* covered by any bodies.

<div class="attention-box">
  We've written a separate page about 
  <a href="{{ "/customising/fms_and_mapit/" | relative_url }}">how FixMyStreet uses MapIt</a>,
  which is the service that determines which area any point (pin) is within. It's
  helpful to understand how that works &mdash; because it also explains how
  FixMyStreet determines which categories of problem can be reported at any
  location &mdash; but the rest of this page is about making and using the boundaries that
  FixMyStreet needs.
</div>

FixMyStreet finds all the bodies that are associated with the area (or areas)
that the pin is inside -- those are the bodies to whom the report might be sent.
Which of these bodies is actually chosen depends on the 
<a href="{{ "/glossary/#category" | relative_url }}" class="glossary__link">category</a>
the user selects when they complete their problem report.

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
<a href="{{ "/glossary/#osm" | relative_url }}" class="glossary__link">OpenStreetMap</a>,
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

## "Everywhere"

This is the simplest boundary: it's infinte, so anywhere the user clicks is
inside the area called "everywhere".

Use this type of boundary if:

   * the bodies you're sending reports to don't depend on the whereabouts of the problem
   * or all the problem reports are always sent to the same, single body
   * you don't mind that FixMyStreet will never reject any problem report because it's too far away

The advantage of using the boundary "Everywhere" is that it's very easy to set
up. The disadvantage is that your FixMyStreet will accept clicks *anywhere* on
the map. This may be acceptable if you are limiting your 
<a href="{{ "/glossary/#geocoder" | relative_url }}" class="glosssary">geocoder</a>
to a very specific area.

<dl class="reveal-on-click" data-reveal-noun="details">
  <dt>
    <h3>How to set this up</h3>
  </dt>
  <dd>
    <p>
      This is the default setup of a new FixMyStreet installation (if you used e.g. the 
      <a href="{{ "/install/install-script" | relative_url }}">installation script</a> or the 
      <a href="{{ "/install/ami" | relative_url }}">AMI install</a>).
    </p>
    <p>
      Set
      <code><a href="{{ "/customising/config/#mapit_url" | relative_url }}">MAPIT_URL</a></code>
      to be blank, and set 
      <code><a href="{{ "/customising/config/#mapit_types" | relative_url }}">MAPIT_TYPES</a></code>
      to the special value <code>ZZZ</code>. FixMyStreet will use a fake MapIt that always
      returns "Everywhere" as the only area that contains the point &mdash; for any
      location.
    </p>
    <p>
      Your <code>conf/general.yml</code> file should contain this:
    </p>
<pre><code>MAPIT_URL: ''
MAPIT_TYPES: ['ZZZ']
MAPIT_ID_WHITELIST: [ ]
</code></pre>
  </dd>
</dl>
 
<a name="approx-area"> </a>
 
## Simple approximate area

Sometimes you just need a boundary to broadly determine if a pin in the map is
too far away from the single area you're receiving reports for.

Use this type of boundary if you:

   * don't need an accurate boundary (for example, _"anything roughly near the town centre is OK"_)
   * do want to prevent problem reports for locations that are not within this area

<dl class="reveal-on-click" data-reveal-noun="details">
  <dt>
    <h3>How to set this up</h3>
  </dt>
  <dd>
    <p>
      You need to install your own MapIt instance, and add the area to that. The
      MapIt admin interface (which uses the Django framework) lets you click-and-draw
      a polygon over a map. Alternatively, we run a MapIt server for custom areas
      like this, so &mdash; especially if you are just doing this as a probationary
      trial &mdash; we may be able to host this for you (note though that we do
      rate-limit calls to MapIt). Either send us 
      <a href="{{ "/glossary/#kml" | relative_url }}" class="glossary__link">KML shape files</a>,
      or if you can't do that, maybe a clear image of the map with the boundary
      drawn on it for us to copy.
    </p>
    <p>
      In your <code>conf/general.yml</code>, you must set 
      <code><a href="{{ "/customising/config/#mapit_url" | relative_url }}">MAPIT_URL</a></code>
      to either your MapIt or our custom one, and set
      <code><a href="{{ "/customising/config/#mapit_types" | relative_url }}">MAPIT_TYPES</a></code>
      to the areas you want (the actual values will depend on what that particular
      MapIt is returning). You should also set 
      <code><a href="{{ "/customising/config/#mapit_id_whitelist" | relative_url }}">MAPIT_ID_WHITELIST</a></code>
      to the ID of the single area you want.
    </p>
    <pre><code>MAPIT_URL: 'http://mapit.example.com'
MAPIT_TYPES: ['CITY']
MAPIT_ID_WHITELIST: [ 133 ]
</code></pre>
  </dd>
</dl>

<a name="approx-areas"> </a>

## Simple approximate areas

This is the same as the previous example, but shows that you can have multiple
areas. This works best if they don't need to be very accurate &mdash; that is,
no colinear borders.

Use this type of boundary if you:

   * don't need an accurate boundary (e.g. anything roughly in an area is OK)
   * the boundaries don't adjoin, or are very simple (no crinkly edges)
   * do want to prevent problem reports for locations that are not within these areas

<dl class="reveal-on-click" data-reveal-noun="details">
  <dt>
    <h3>How to set this up</h3>
  </dt>
  <dd>
    <p>
      Same as previous example: either set up your own instance of MapIt, or ask to
      have your boundaries added to our custom one. If you want us to host it, we'll
      need <a href="{{ "/glossary/#kml" | relative_url }}" class="glossary__link">KML shape files</a>
      or a graphic showing the boundary clearly shown so we can copy it. 
    </p>
    <p>
      Note that now there may be more than one type of area, and you'll need to explicitly
      nominate every area you're interested in with
      <code><a href="{{ "/customising/config/#mapit_id_whitelist" | relative_url }}">MAPIT_ID_WHITELIST</a></code> 
      (unless you want *all* the areas this MapIt returns for the given type, in
      which case you can set it to be empty).
    </p>
    <pre><code>MAPIT_URL: 'http://mapit.example.com'
MAPIT_TYPES: ['CITY', 'COUNTY']
MAPIT_ID_WHITELIST: [ 133, 145, 12, 80 ]
</code></pre>
  </dd>
</dl>
  
<a name="mysociety-mapit"> </a>

## Accurate OpenStreetMap data

It's possible that the admin boundaries of local government in your area are
already available in the OpenStreetMap project. If this is the case,
FixMyStreet can automatically use them. **This is the easiest solution if the
data you need is there** because we already run two servers 
([UK MapIt](https://mapit.mysociety.org) and 
[global MapIt](http://global.mapit.mysociety.org))
that make this data available.

Use this type of boundary if:

   * the boundary data for the areas you need is already on OpenStreetMap

<dl class="reveal-on-click" data-reveal-noun="details">
  <dt>
    <h3>How determine if the boundary data is available</h3>
  </dt>
  <dd>
    <p>
      Start by finding the <a href="{{ "/glossary/#latlong" | relative_url }}"
      class="glossary__link">lat-long</a> of some of the places you want to cover,
      and look them up on <a href="http://global.mapit.mysociety.org">global
      MapIt</a> (or maybe the <a href="https://mapit.mysociety.org">UK one</a>).
      If you see the "Areas covering this point" include the admin
      boundaries you need, you're good to go! For example, here's
      the <a
      href="http://global.mapit.mysociety.org/point/4326/10.75,59.95.html">page
      for Oslo, in Norway</a>.
    </p>
    <p>
      Note that our MapIt servers' data may lag a little behind OSM, so
      if it's not there, look on the
      <a href="http://www.openstreetmap.org">OpenStreetMap website</a> just in
      case it's been added since MapIt's last update. If so, let us
      know, and we'll pull it in for you.
    </p>
    <p>
      Here's an example of the steps to follow to find the data you need
      to use global MapIt. This example uses Zurich as an example city.
    </p>
    <ol>
      <li>
        <p>
          Go to <a href="http://nominamtim.openstreetmap.org">OpenStreetMap's
          geocoder</a> and enter the name of the city, e.g., "Zurich,
          Switzerland".
        </p>
      </li>
      <li>
        <p>
          Check that's found the right place (and, if you want, check the map
          is how you expected). Click on the <strong>details</strong> link just
          below the name of the top hit. The details page lists lots of data,
          including the centre point (lat/long values that will look something
          like <code>-34.9059039,-56.1913569</code>).</p></li> <li><p>Go to <a
          href="http://global.mapit.mysociety.org">global MapIt</a> and paste
          those lat/long values into the text input.
        </p>
      </li>
      <li>
        <p>
          MapIt will show you all the <a
          href="http://global.mapit.mysociety.org/point/4326/8.55,47.366667.html">admin boundaries</a>
          that contain that point. You're interested in
          the ones that relate to bodies that serve those areas. For example,
          if a district council fixes the potholes in that district.
          Specifically, you need the <strong>Administrative Boundary
          Levels</strong> (which will look like <code>O04</code> or
          <code>O05</code>), which are the values for your 
          <code><a href="{{ "/customising/config/#mapit_types" | relative_url }}">MAPIT_TYPES</a></code>.
          Remember this data is boundary data from OpenStreetMap &mdash;
          if the boundaries you need are not shown, you may have to set up your
          own (described below). You can also click on any of the boundaries
          listed on MapIt to see the areas they actually cover on the map.
        </p>
      </li>
      <li>
        <p>
          The individual <em>area_id</em>s are also useful, because you put
          them into the <code><a href="{{ "/customising/config/#mapit_id_whitelist" | relative_url }}">MAPIT_ID_WHITELIST</a></code>.
        </p>
      </li>
    </ol>
  </dd>
  <dt>
    <h3>Using our MapIt servers: some restrictions</h3>
  </dt>
  <dd>
    <p>
      We run two public MapIt services: <a
      href="https://mapit.mysociety.org">mapit.mysociety.org</a> covers the UK
      (because that's where we're based, and it serves our own 
      <a href="www.fixmystreet.com">UK FixMySteet</a> site), and 
      <a href="http://global.mapit.mysociety.org">global.mapit.mysociety.org</a>,
      which covers the whole world. The data we use for global MapIt is from
      <a href="http://www.openstreetmap.org">OpenStreetMap</a>, so if someone has
      put administrative boundary data for your country into OSM, before too
      long global MapIt will have it too.
    </p>
    <p>
      Please get in touch with us if you are expecting to generate a lot of
      requests or <strong>if you are using it commercially</strong>. We
      rate-limit calls to MapIt, so if your site gets really busy, you should
      set up your own instance (we can help you, and the <a
      href="https://github.com/mysociety/mapit">code is on GitHub</a>). But when
      you're setting your site up to begin with, you can usually get it running
      using one of our MapIt servers.
    </p>
  </dd>
  <dt>
    <h3>How to set this up</h3>
  </dt>
  <dd>
    <p>
      In your <code>conf/general.yml</code> file, point 
      <code><a href="{{ "/customising/config/#mapit_url" | relative_url }}">MAPIT_URL</a></code>
      at the global MapIt server.
    </p>
    <p>
      Find the areas you need by looking on the
      <a href="http://global.mapit.mysociety.org">global MapIt website</a> or the
      <a href="https://mapit.mysociety.org">UK one</a>. You must also nominate
      the types of area these are (effectively the <em>level</em> of admin
      boundary it is), and the generation. On global, the area types look
      something like <code>[ 'O05', 'O06' ]</code>. (Note those contain capital
      letter O followed by digits). To determine what types you need, look for
      the codes marked &#8220;Administrative Boundary Levels&#8221; that MapIt
      returns &mdash; for example, here's
      <a href="http://global.mapit.mysociety.org/point/4326/8.55,47.366667.html">global
      MapIt's data for Zurich</a>.
    </p>
    <p>
      The UK MapIt types are different. For example, for UK FixMyStreet, we use:
    </p>
<pre><code>MAPIT_TYPES: [ 'DIS', 'LBO', 'MTD', 'UTA', 'CTY', 'COI', 'LGD' ]
</code></pre>
    <p>
      which covers all the UK council types (for example, <code>DIS</code> is district council,
      <code>CTY</code> is county council).
    </p>
    <p>
      Finally, limit your installation to the specific areas you're interested
      in (otherwise you'll be getting areas from the whole world). Identify the
      specific areas you want to use, and list them explicitly in
      <code><a href="{{ "/customising/config/#mapit_id_whitelist" | relative_url }}">MAPIT_ID_WHITELIST</a></code>.
      You should also set
      <code><a href="{{ "/customising/config/#mapit_generation" | relative_url }}">MAPIT_GENERATION</a></code>, 
      so that your areas can still be found when we update the global MapIt data.
    </p>
<pre><code>MAPIT_URL: 'http://global.mapit.mysociety.org'
MAPIT_TYPES: ['O06','O07']
MAPIT_ID_WHITELIST: ['12345','345432','978638']
MAPIT_GENERATION: 3
</code></pre>

  </dd>

</dl>

<a name="accurate"> </a>

## Accurate data that isn't on OSM

Use this type of boundary if:

   * you need accurate boundaries because the different bodies that
     solve problems in your region serve specific areas that are geometrically
     complex and/or are precisely adjacent 
   * the boundary data for the areas you need are not already on OpenStreetMap
   * but you do have access to this data from some other source

This means you have to source the data yourself -- either by getting your local
government to release it, or else drawing it yourself. Then you need to import
this data into a MapIt server and use that.

<dl class="reveal-on-click" data-reveal-noun="details">
  <dt>
    <h3>How to set this up</h3>
  </dt>
  <dd>
    <p>
      Ideally, if you can source the data from your local government (which
      means it's definitive), then it's great if you can add it (as
      admin boundary data) to the OpenStreetMap project. Our global MapIt will
      subsequently import it and your FixMyStreet can then use it as described
      in the previous example. If you're going to do that, <strong>the
      data must be open data</strong> and you should probably ask about it on
      the <a href="http://lists.openstreetmap.org/listinfo/imports">OSM import
      list</a> first. Of course, if you do this then anyone else in the world
      who wants the data will be able to use it too, which is why we encourage
      this approach.
    </p>
    <p>
      But if you can't do that, or the boundary data you have is not
      definitive, you can create your own. Use any good GIS software to plot
      the boundaries accurately, and then export it as
      <a href="{{ "/glossary/#kml" | relative_url }}" class="glossary__link">KML shape files</a>.
      MapIt can import these, so you can then either run your own MapIt
      instance, or ask us to add it to our custom one.
    </p>
  </dd>
</dl>

## Can you see the boundaries?

FixMyStreet doesn't normally display the admin areas and boundaries on the maps
(mainly because most users really don't care &mdash; they just want to report
a problem). But it *is* possible, with some customisation, to change this
behaviour. 

If you just want to see a boundary drawn on a map to check that it's covering
the area you want, you can see this by going to the MapIt server it's on, and
looking at that area's HTML page. For example, see the [boundary for
Norway](http://global.mapit.mysociety.org/area/363186.html) on the global MapIt
server.



