---
layout: default
title: How FixMyStreet uses MapIt
author: dave
---

# How FixMyStreet uses MapIt

<p class="lead"> When you add a body to FixMyStreet, you specify which areas
it covers. The areas are typically defined by administrative boundaries: these
are <em>not</em> part of FixMyStreet, but are made available through our
service called MapIt. </p>

Note that MapIt tells FixMyStreet what administrative boundaries a point lies
within: it does not actually draw the maps (by default, FixMyStreet uses
OpenStreetMap for that).

## How this works

When someone places a pin on the FixMyStreet map to report a problem,
FixMyStreet sends the coordinates (lat, long) of that position to MapIt. MapIt
responds with a list of the areas that the pin lies within. FixMyStreet then
looks in its own database to find all the bodies that cover that area, and the
contacts (which are usually email addresses) that you have added for each of
those bodies. Because each contact is associated with a category of problem
(for example, "Potholes" or "Graffiti"), FixMyStreet can build a list of all
the problem categories that *can* be reported at this location. In fact, this
list appears as the drop-down menu ("Pick a category") on the report-a-problem
page.

This means that your FixMyStreet installation must be able to connect to a
MapIt service which knows about the administrative areas in your part of the
world.

## Detailed flow: location &rarr; map pin &rarr; drop-down menu

![FMS bodies and contacts](/images/fms_bodies_and_contacts.png)


# Three ways FixMyStreet can use MapIt

There are three ways to use MapIt with your FixMyStreet installation.

1. just assume everywhere is within one boundless area
2. use mySociety's MapIt servers (OpenStreetMap data)
3. use your own MapIt server with custom data


## 1. FakeMapIt: Everything is in One Area

The simplest setup is to assume *everywhere* is covered by a single area
(called `Default area`). This is so simple that actually the default setup for
FixMyStreet behaves in this way. It connects to its own internal "FakeMapIt",
which responds with the same area every time.

This is all you need if you just want to get your installation up and running,
or don't need to send reports to different bodies simply because they are in
different places.

To use this approach, in the configuration, set `MAPIT_URL` to be blank
(because you're not really connecting to a real MapIt service at all), and set
`MAPIT_TYPES` to `[ 'ZZZ' ]`, which is a list containing the single type that
FakeMapIt always returns for the Default Area.


## 2. Use mapit.mysociety.org

We run two public MapIt services:
[mapit.mysociety.org](http://mapit.mysociety.org) covers the UK (because
that's where we're based, and it serves our own [UK
FixMySteet](www.fixmystreet.com) site), and
[global.mapit.mysociety.org](http://global.mapit.mysociety.org), which covers
the whole world. The data we use for global MapIt is from
[OpenStreetMap](http://www.openstreetmap.org), so if someone has put
administrative boundary data for your country into OSM, before too long global
MapIt will have it too.

We rate-limit calls to MapIt, so if your site gets really busy, you should set
up your own instance (we can help you, and the [code is on
github](http://github.com/mysociety/mapit)). But when you're setting your site
up to begin with, you can get it running using one of these two servers.

To use the mySociety MapIt instances, set `MAPIT_URL` either to
`http://mapit.mysociety.org/` (UK) or `http://global.mapit.mysociety.org/`.
You **must** also list the `MAPIT_TYPES` you are interested in: different
types of area have a different code. For example, for UK FixMyStreet, we use:

    [ 'DIS', 'LBO', 'MTD', 'UTA', 'CTY', 'COI', 'LGD' ]

which covers all the UK council types (for example, `DIS` is district council,
`CTY` is county council). If you're using global mapit, the area types look
something like `[ 'O05', 'O06' ]`. (Note those contain capital letter O
followed by digits). To determine what types you need, look for the codes
marked "Administrative Boundary Levels" that MapIt returns -- for example,
here's [global MapIt's data for
Zurich](http://global.mapit.mysociety.org/point/4326/8.55,47.366667.html).

### Whitelisting specific areas

It's quite common for people setting up localised FixMyStreet to know exactly
which areas they are interested in. If this applies to you, you can specify a
`MAPIT_ID_WHITELIST` which explicitly lists *only* those area IDs (returned by
global MapIt) that your installation will use. For example,

    MAPIT_ID_WHITELIST: [ 240838, 246176, 246733 ]

FixMyStreet will work fine if you leave the whitelist blank, which is the
default. But if your FixMyStreet is only using a few areas, it's more
efficient to specify them in this way.


### Missing OSM boundary data?

If you want to use global MapIt, but the OSM data does not cover your country,
there are two things you can do. Ideally, find the boundary data you need
(maybe the government publishes it?) and add it to OpenStreetMap, so that
MapIt global can use it. If you're going to do that, **the data must be open
data** and you should probably ask about it on the [OSM import
list](http://lists.openstreetmap.org/listinfo/imports) first. Of course, if
you do this, it means anyone else in the world can use it too, if they want.

Alternatively, if you can't get accurate boundary data, you can set up your
own MapIt instance that just covers what you need in order to get your
FixMyStreet working, which is described below.


## 3. Set up your own MapIt

If neither 1. or 2. work for you, you can
[set up your own installation of MapIt](http://code.mapit.mysociety.org/install/),
and add your own areas. The
[code is on github](http://github.com/mysociety/mapit)
and is a simple Django project. Once you've got that running, it's easy to add
new areas: the admin lets you draw your boundary over a map in the web browser
and save it. You have to specify what kind of area it is too, with a type: use
any three-letter code that makes sense (in the UK we use `DIS` for District
councils, but you can use anything you want).

The advantage of this is you can just add the data you need (for example, if
you're getting FixMyStreet to work on a couple of islands, and you need them
to be different areas, the chances are you don't need super-accurate official
boundary data: just draw a close polygon around the coast). You only need to
be as accurate as your FixMyStreet requires.

If you want to run your own MapIt, set the `MAPIT_URL` to the URL of your custom installation, and list the `MAPIT_TYPES` that match the types you entered when you added your own areas, for example, `[ 'ABC', 'XYZ ]`.


## Some notes

If you do want to use our UK or global MapIt services, but need it to not be
rate-limited, let us know. We can either help you set up your own (with the
OSM data in it), or perhaps arrange to run one for you.

Note that **more than one body can cover the same area** (actually it's quite
common) -- for example two national bodies (the Highways Department and the
Water Department) would both have the same (national) boundary data.

One useful consequence of the way you set up the areas (in MapIt) and bodies
(in FixMyStreet) is that **nobody can report a problem at a location that is
not in an area covered by a body**. This means, if someone tries to place a
pin in an area covered not by your FixMyStreet (for example, in the middle of
the sea), the application will be able to tell the user that that location is
not supported. Of course, this is the drawback of using FakeMapIt: every
location is always _within_ the boundary of the "Default area".

