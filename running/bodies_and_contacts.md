---
layout: page
title: Bodies and Contacts in FixMyStreet
author: dave
---

# Managing bodies and contacts in FixMyStreet

<p class="lead">A <strong><a href="/glossary/#body" class="glossary">body</a></strong> is the authority to which problem
reports will be sent. Each body needs one or more <strong><a href="/glossary/#contact" class="glossary">contacts</a></strong>
(typically these are email addresses) to which particular
<strong><a href="/glossary/#category" class="glossary">categories</a></strong> of problem are sent. </p>

For [FixMyStreet in the UK](http://www.fixmystreet.com/), bodies are councils (county, district, and metropolitan).

## How to add (or edit) a body

You need access to the administration pages of your FixMyStreet installation.
By default, this is at `/admin`.

Click on **Bodies** and fill in the form. Normally, you _must_ provide a name
and pick at least one area it covers. See [How FixMyStreet uses
Mapit](/customising/fms_and_mapit) for more information on how these areas are chosen.

You can specify a <strong><a href="/glossary/#send-method" class="glossary">send method</a></strong>. This is *how* FixMyStreet will send the
problem reports to this body.

If you leave it blank, **send method will default to email**.

A body can have none, one, or many contacts. We strongly recommend every body
has at least one.

## Add contacts for every category of problem this body can handle

Even if you only have one email address for the body, you can add multiple
contacts, because each contact is for a particular **category** of problem. So
even if all the contacts' email addresses are the same, FixMyStreet treats
them separately. This often makes sense because the body passes these reports
on to different departments internally. This is also the mechanism FixMyStreet
uses to describe the category of the problem to the body: it's included,
clearly, in the email that is sent.

Here's an example of a body and its contacts:

    Body: South Borsetshire District Council

    Contacts:

      Category              Email
      ---------------------------------------------------
      Bridges               road_department@sbdc.gov.uk
      Potholes              road_department@sbdc.gov.uk
      Traffic lights        road_department@sbdc.gov.uk
      Graffiti              services@sbdc.gov.uk
      Street lighting       lights@sbdc.gov.uk
      Other                 enquiries@sbdc.gov.uk

Problems about bridges, potholes, and traffic lights in South Borsetshire all
get sent to the same email address. Don't worry about the order in which the
contacts appear in the admin, because FixMyStreet sorts them before presenting
them to the user.

The FixMyStreet admin makes it easy to change your setup if the body changes
its email addresses or even adds a new department after your site is running.

<div class="attention-box warning">
<h3>A body with no contacts will never receive any reports</h3>
<p>
We do not recommend you run your installation of FixMyStreet with bodies that
have no contacts. Problems submitted to such a body will remain on the site
but will not be sent. Problems like this may never get fixed.
</p>
<p>
You really need to find at least one working contact for each body to which
you want to send reports. This isn't a technical problem, but it can be one of
the more difficult parts about setting up FixMyStreet.
</p>
</div>

### Normally, contacts use email addresses

In most new installations, each contact needs an email address because
FixMyStreet will send the problem report to the body by email (that's the
default **send method** for bodies). Make sure you enter the correct email
address! Note that the public users of FixMyStreet do not automatically see
these email addresses, because FixMyStreet sends them directly to the body and
not to the user.

If you're only using email as the send method (which is by far the most
common), you don't need to provide any more data (such as endpoints or API
keys). These fields are for alternatives to email.

### Alternatives to email addresses

Although the default method for sending reports is email, there are other ways
of sending the reports. Note, though, that alternatives to email are only
possible if the body to which you are trying to send reports supports them.
Some do; many do not.

We like [Open311](http://www.open311.org/), which is an open standard for
submitting problem reports to a body automatically (by sending the data
directly to a webservice that consumes it). FixMyStreet also has a number of
other, custom, methods for submitting data that we've written for specific
councils in the UK: if you need to write your own, look at the code or ask us
to help you. Custom integrations can be difficult, depending on how easy it is
to get data in and out of the body's internal, back-end systems.

You can change a body's send method -- for example, if you start by sending
emails, but then discover the body is running an Open311 server, it's easy to
change over. Note that if you choose a different send method, FixMyStreet will
need some extra information, such as the URL of the body's endpoint. This
appears on the form if it's needed.

For more information about Open311, see [this blog post explaining
it](http://www.mysociety.org/blog/open311-explained).

#### Not all of a body's contacts need to be sent the same way

In fact, if you're working on an installation that can connect to bodies using
a method other than email, not *all* of a body's contacts need to be sent the
same way. It's possible to specify a different **send_method** for an
individual contact. You'll need to edit the body (in `/admin`) and check the
box marked "Contacts can be devolved". Then mark each of the contacts that are
not using the body's send method (which by default is email) as "devolved",
and specify their own send method and details.

## Deleting contacts

If a contact is no longer valid, you can delete it. Find it on the body's admin page, click to edit it, and check **deleted**.

This does not remove the contact from the FixMyStreet database (because doing
so might break any existing problem reports that used it), but it prevents the
contact from being used for new reports.


