---
layout: page
title: Integration
author: dave
---

# Integrating FixMyStreet with back-end systems

<p class="lead">
  By default, FixMyStreet uses email to send problem reports to the body
  responsible for fixing them. But it's best if sending reports is
  <strong>integrated</strong> directly, so that problems are injected directly
  into the body's back-end system.
</p>

## Integrate if you can!

Often <a href="{{ "/glossary/#body" | relative_url }}" class="glossary__link">bodies</a>,
especially if they are local government bodies, already have databases and
back-end systems for tracking problems they are fixing. FixMyStreet works fine
if you just use the default <a href="{{ "/glossary/#send-method" | relative_url }}"
class="glossary__link">send method</a>, which is email, but it's *much better* if you
can integrate with the body's back-end systems.

How hard this is depends on the kind of system the body is using, and how much
cooperation they offer FixMyStreet. In general, once FixMyStreet is integrated
it's *easier* for the body's staff to use.

Our experience with FixMyStreet in the UK is that councils that integrate with
FixMyStreet also choose to run it as a <a href="{{ "/glossary/#cobrand" | relative_url }}"
class="glossary__link">cobrand</a> (that is, branded and on their own website). In
fact, cobranding and integrating are not dependent on each other, so if you do
one it is not necessary to do the other.

## Levels of integration (and their benefits)

<ol start="0">
  <li>
    <strong>no integration</strong> (the default)<br>
    reports are sent by email
  </li>
  <li>
     <strong>reports are injected directly into the back-end</strong>
     <br>
     so staff don't have to copy-and-paste from emails &mdash; furthermore,
     if the body returns its own reference for the report, then FixMyStreet
     can publish it
  </li>
  <li>
     <strong>status changes on the back-end propogate to FixMyStreet</strong>
     <br>
     so staff don't have to log in to FixMyStreet and mark 
     problems as "fixed" by hand... and FixMyStreet publicises the
     work that the authorities are doing
  </li>
  <li>
     <strong>problems created in the back-end appear on FixMyStreet</strong>
     <br>
     so all the problems the body is working on are public
  </li>
</ol>

Although you can approach each of these levels of integration as custom
programming tasks, we *strongly recommend* you use the
<a href="{{ "/glossary/#open311" | relative_url }}" class="glossary__link">Open311</a>
open standard when you can.

Strictly speaking it's possible to implement any of these levels independently
of the others. In practice, though, each one tends to follow on from the
previous one.

## You don't need to integrate *everything*

You can integrate with just one body (while the others continue to use email).
You can even just integrate certain
<a href="{{ "/glossary/#category" | relative_url }}" class="glossary__link">categories</a>
for a body &mdash; for example, "Potholes" and "Fallen trees" could be
submitted by Open311, while "Streetlighting" problems are sent by email.

## No integration: send reports by email

With **no integration**, problem reports are sent by email:

<img src="/assets/img/fms_integration_0.png">


## Stage 1: Injecting directly into the back-end

With the **first level of integration**, problem reports are injected directly
into back-end:

<img src="/assets/img/fms_integration_1.png">


If the body's server is already <a href="{{ "/glossary/#open311" | relative_url }}"
class="glossary__link">Open311</a> compliant, you can switch on the first stage
of integration -- which puts the problem report directly into the body's
back-end system instead of emailing it -- just by setting the send method (for
the body, or for specific categories) to Open311.

To enable Open311 for a body, edit in in the admin and set **send method** to
"Open311". A form will appear for Open311 connection details including, for
example, the body's endpoint URL. It's common for Open311 endpoints to require
an API key and possibly access criteria before they will accept Open311 service
requests. You'll probably need to talk to the body's IT team to be granted
access -- for example, they may only open a port to your server's single IP
address.

If you want to have the problem reports for some categories to be integrated
into their body's back-end, but continue to send others by email, you can
<a href="{{ "/glossary/#devolve" | relative_url }}"
class="glossary__link">devolve</a>
choosing the send method to the contacts. Set the body's send method as above,
but also enable **contacts can be devolved**. Now you can set specific
contacts' *send methods* to `email`, which will override the body's send method.

### Passing external IDs between the two systems

When a problem report is successfully posted to the body over Open311, usually
the back-end responds with the body's reference. FixMyStreet stores this in the
`problem` record as the `external_id` (because from FixMyStreet's point of view,
the back-end is the external system).

In our experience, bodies integrated in this way often want to know the
FixMyStreet ID for the report, to store at their end. From the body's point of
view, FixMyStreet is the external system, so we usually pass this to them in
the Open311 POST request as `attribute[fixmystreet_id]`. If the body sets up
their Open311 server to request this attribute, we will automatically fill it.
If they want the field named differently, you will need to store it as the
`id_field` extra metadata on the relevant contacts.

### What if the back-end system is not Open311 compliant?

If the body you want to integrate with does not yet support the Open311 standard,
you can still integrate with it, but it takes a little more work. If the back-end
offers an alternative way to post new problem reports into it, then you'll need to
code it. Typically this could involve either adding a custom Perl module to
`perlib/FixMyStreet/SendReport`, or writing a 'proxy' server that receives Open311
data from FixMyStreet (so it *is* Open311 from FixMyStreet's point of view) and
then sends on differently formatted data elsewhere.

We *strongly recommend* you try to implement the Open311 standard instead, but
you might well not be able to change the back-end system (often these are
large, proprietary and inflexible systems), so you may be able to implement a
shim that makes it behave like one. For example, in the UK we integrate with a
number of councils whose back-end does not use the Open311 standard, by running
a script either on our or their server, which accepts incoming Open311 requests
and converts them into custom calls. The script captures the result and sends
it back as the appropriate Open311 response. We have an
[example](https://github.com/mysociety/open311-adapter) of one adapter we use
on GitHub.

The advantage of this approach is that, to FixMyStreet, the body uses the tried
and tested Open311 send method. The benefit to the body is that should their
back-end one day implement the Open311 standard, or they change to using one that
does, then no changes will be necessary other than to remove the scripts.


## Stage 2: Automatically updating problem statuses

With the **second level of integration**, not only are reports injected
directly into the back-end, but back-end status changes automatically propogate
*back* to FixMyStreet:

<img src="/assets/img/fms_integration_2.png">

When the body fixes a problem, they mark it as fixed in their back-end system.
Stage 2 integration detects this change and automatically updates the record
on FixMyStreet. Typically this means marking the problem as fixed (turning the
pin green, if configured to do so) and optionally adding a description from the
council.

A basic form of this is in the Open311 standard, but we prefer a slight extension
(which we think should be: see [this
explanation](https://www.mysociety.org/2013/02/20/open311-extended/)) and it
requires the back-end to expose update data.

Our experience is that most back-ends do not already provide this data, but that
it is a relatively easy for them to implement if they choose to do so. For
example, on a typical problem database, one method is to add a trigger that
detects whenever the status of a problem changes (for example, is marked as
fixed), and record the time and status change in a new table. FixMyStreet polls
the back-end for updates within certain time bounds ("have any problems' statuses
changed in the last 15 minutes?"), which effectively reads from
this new table.

FixMyStreet adds these changes automatically as updates on the public site: for
example, marking a problem as fixed with either a custom comment send from the
back-end or else a boilerplate one (for example, "Fixed by Borsetshire Council
road crew").

In order to set this up you first need to liaise with the body to make the
update data available. You can then enable it by editing the body in the admin,
and enabling **Open311 update-sending**. You also need to nominate a FixMyStreet
user to which all these updates will be credited (for example, "Borsetshire
Council") -- if necessary you can create a user just for this purpose at
`/admin/users`.

The mechanism we use for propogating fixes (and other status changes) from the
back-end to the FixMyStreet site is deliberately light on the body. That is,
once the body has implemented the update table (or its equivalent), FixMyStreet
is responsible for polling the back-end -- there's no requirement for the body's
system to do anything other than respond to these requests. Furthermore, when it
does so, it uses the back-end's own reference (stored in FixMyStreet's database
as the `external_id`) to identify problem reports, so there is no requirement
to use the FixMyStreet ID. Because FixMyStreet polls regularly (typically
every 15 minutes thoughout the day, with a single 24-hour mop-up once during
the night), any problems connecting or tracking which updates have been picked
up are handled at the FixMyStreet end.

## Stage 3: Displaying problems not originating on FixMyStreet

With the **third level of integration**, problems reported by staff on the
back-end are shown on FixMyStreet too:

<img src="/assets/img/fms_integration_3.png">

The third level of integration is for *all* problem reports on the back-end to be
displayed on the FixMyStreet system. Before doing this, you need to consider:

   * how the body decides which, if any, reports should be excluded
   * importing existing records (typically a big batch job, since there may be very many)
   * ensuring imported categories all match
   * ongoing acquisition of new records as they are added (feasible using Open311)

Talk to us before doing this level of integration. Our experience is that levels
1 and 2 are higher priority both for public users and for the authorities, so it's
a good idea to implement those first.
