---
layout: page
title: Using FixMyStreet with SMS
---

# Using FixMyStreet with SMS

<p class="lead">
  We're sometimes asked about running FixMyStreet with
  <a href="{{ "/glossary/#sms" | relative_url }}" class="glossary__link">SMS</a>.
  With SMS, users can report problems by text message instead of using the web
  interface. This page describes how it can work, and what you must consider
  before going ahead.
</p>

Adding SMS capability to your FixMyStreet site is, on the face of it, a great
idea. In theory, it allows people with non-internet enabled handsets, or with
no data network coverage, to report problems. Such people may represent a large
and important section of the local population who might otherwise be unable to
use the service. However, it's important to appreciate what the limitations of
SMS are, and why we always recommend you establish and run your site on the web
*before* you try to add SMS capability to it.

## Limitations of SMS

### Main issues: duplicate reports, no location information

One important aspect to FixMyStreet is that most 
<a href="{{ "/glossary/#report" | relative_url }}" class="glossary__link">problem reports</a> are about problems with specific locations. On the web, this
means we can present the user with a map to click on.

This interface, encouraging people to click on a map, serves a couple of functions: 

   * it deters duplicate reports being sent for the same problem, because it's obvious if a problem has already been reported (a pin will already be there)

   * it provides an accurate 
     <a href="{{ "/glossary/#latlong" | relative_url }}" class="glossary__link">lat-long</a>
     position of the location of the problem

The main problem with SMS &mdash; although there are others &mdash; is that
both of these benefits are lost. So although SMS may be beneficial because it
doesn't require a more powerful device or interface capability, these are two
significant drawbacks. Both of them require your team to process the incoming
reports -- either to detect and intecept duplicate reports, or to identify the
precise location of a problem where this is not clear.

<div class="attention-box info">
  In effect, this means that adding SMS capability to FixMyStreet <em>increases
  the burden on the support team running the site</em>. Or, if it doesn't, then
  this burden is passed directly on to the authorities who are receiving the
  reports &mdash; and you should not run your site in this way.
</div>

This is not to say it should not be done, just that if you do it you must
appreciate that you will not be making your team's lives easier. Of course, you
might be making things easier for the citizen users, but this will only happen
if your team is able to handle the work it may generate. It might not be a lot
of work -- that depends on how the system is used, and how widely -- but it
will certainly not be less work.

We have also encountered misunderstanding about using geolocation on mobile
devices. The technical issue here is secondary &mdash; the main point is that
FixMyStreet doesn't need the location of the *handset*; it needs the location
of the problem being reported. This distinction is handled by the web
interface, but not when using SMS. See
*[Geolocating via SMS](#geolocating-via-sms)* below for more details.

So, we have two approaches to this, and we always recommend anyone looking to
add SMS reporting capability to FixMyStreet tries the first one (method 1,
below) first.

In both cases, you start by advertising a number (possibly a shortcode which is
easier for people to remember) for people to send SMS reports to. This means
you should
[customise your templates]({{ "/customising/templates" | relative_url }}), because (when it's running live) the number should presumably appear on the website
too.

## Method 1: use a mobile phone (yes, really!)

<div class="attention-box info">
Have all incoming message go to a mobile phone your team has access to. They
then create problem reports in the FixMyStreet using their staff login, on behalf
of the reporter.
</div>

The main reason for doing this is you get to discover just how badly needed SMS
input is. If nobody sends reports to you, you've discovered that it's not in
demand, and you haven't invested any time in integrating SMS into the system.
And if they do, you get a good idea of the kind and quality of the reports you
will be receiving.

The downside of this is that the reports you create are not in the name (or
account) of the sender -- this may be more of a problem than you might realise,
because it means that the body (the council) who eventually gets the report
cannot reply directly (unless you also pass on the phone number -- note that
you typically won't know the name of the citizen either, as you've probably only
got their number).

It's likely that you will need to reply to some incoming SMSs to clarify the
nature of the report (especially to pinpoint the location if it's not clear),
which you can do from the mobile phone. Of course there is an implicit cost to
this because you're sending an outgoing messages from the mobile phone each time.

## Method 2: use an SMS gateway

<div class="attention-box info">
Use "Message Manager" integrated with an SMS gateway. Your staff can access
the messages using their staff login, and create problem reports on behalf
of the reporter.
</div>

We have a web application called 
<a href="{{ "/glossary/#message-manager" | relative_url }}" class="glossary__link">Message Manager</a> that accepts incoming messages from an SMS gateway, and makes them available to
<a href="{{ "/glossary/#staff-user" | relative_url }}" class="glossary__link">staff users</a>
within the FixMyStreet website. A staff user on a FixMyStreet site that is
using Message Manager can see incoming SMS reports, reply to them, and turn
them into reports by clicking on the map. This effectively integrates SMS
messages to FixMyStreet but it's very important to understand this does not
automate the creation of reports. We do not do that, because of the subtleties
described above: the location of the problem is often vague, and the submission
may be a duplicate report anyway.

The advantage of using Message Manager is that the reports are easier for
trained staff to manage, because it's all happening in the web browser. Reports
submitted in this way are marked as such ("via mobile") on the site. It also
tracks the conversation threads for any replies. Commonly, your staff may need
to clarify details with the original reporter before the report can be
accurately made. Message Manager allows those replies to be sent from within
the browser too, and maintains them as threads. It also supports a certain
amount of processing based on codes within the message, for example, incoming
messages can be automatically classified by looking for prefix codes (e.g.,
"to report problems in the Foo district, text 'FOO pothole outside
Example Shop in Demo Street").

So, Message Manager makes sense if you're getting a lot of SMS messages and
your team is willing to handle them.

But there are two big caveats: firstly, it is not straightforward to set up,
because it needs to be integrated with an SMS gateway that is using the
advertised number or short code. This integration almost certainly requires
custom coding depending on the characteristics of whichever SMS gateway you use
(for example,
[this is the code](https://github.com/mysociety/message-manager/blob/master/app/Console/Command/NetcastShell.php)
we wrote so that Message Manager could run with the NetCast SMS gateway in the
Philippines). Also, of course there is a cost involved in using an SMS gateway,
typically both for its setup (for receiving messages), its ongoing service, and
possibly charges for outgoing messages.

And remember, accepting SMS messages through an SMS gateway with Message
Manager does not lessen the burden of work on your team, it adds to it. It just
makes that work a little easier because it's possible to handle everything
entirely in a web browser, and there's a little less typing to do.

## Process/comparison of methods

<table class="table">
  <tr>
    <th></th>
    <th>
      Method 1:<br>mobile phone receiving SMS directly
    </th>
    <th>
      Method 2:<br>Message Manager via SMS&nbsp;gateway
    </th>
  </tr>
  <tr>
    <td>
      Set up
    </td>
    <td>Practically none</td>
    <td>
      Potentially complex:
      <br>
      Install MM and create MM admin user(s),
      configure with FMS (including CORS),
      integration with SMS gateway  (requires local testing),
      authorise nominated staff accounts,
      configure prefixes if used
    </td>
  </tr>
  <tr>
    <td>
      Incoming messages
    </td>
    <td>arrive in phone's inbox</td>
    <td>appear in message list in FMS, when logged in as staff</td>
  </tr>
  <tr>
    <td>
      Report creation (staff&nbsp;user)
    </td>
    <td>click on map, copy text manually from phone, select category</td>
    <td>click on message, click on map: message text appears in the report, select category</td>
  </tr>
  <tr>
    <td>
      How location is determined
    </td>
    <td>
      staff user clicks on map
    </td>
    <td>
      staff user clicks on map
      <br>
      Area can be automatically detected by prefix
      in SMS message
    </td>
  </tr>
  <tr>
    <td>
      Reply to user (i.e., send SMS)
    </td>
    <td>by replying to incoming message (staff user sees the texter's phone number)</td>
    <td>via the SMS gateway (can be configured not to reveal phone numbers to staff users)</td>
  </tr>
  <tr>
    <td>
      FMS records this as coming via SMS
    </td>
    <td>
      not automatically
    </td>
    <td>
      yes
    </td>
  </tr>
  <tr>
    <td>
      automatic notification of status change
      (e.g., when fixed)
    </td>
    <td>no<br>&nbsp;</td>
    <td>no<br>(but theoretically possible)</td>
  </tr>
</table>

<img src="/assets/img/fms_with_sms_flowchart.png">


## Geolocating via SMS

Finally, a note about geo-location via SMS: some people get enthusiastic about
being able to automatically detect the location an SMS was sent from. It's
important to remember, in the context of FixMyStreet, that even if you can
determine the location from which an SMS was sent (technically, SMS itself does
not provide such a capability, but some network providers may offer a service
which does a similar thing) this isn't automatically *useful*.

The problem is this: very often a report to FixMyStreet is not being made from
the location of the problem. That means you don't care where the phone is; you
care where the problem (e.g., the pothole) is. This works fine with the web
interface where the user can (if they want, and if the device supports it) use
their current location which the device can automagically supply. But there's
no such interface with SMS, and even if there was a reliable way to identify
the location of the sender, we would warn agains sending reports on to the body
responsible for fixing them when there's no way of knowing if the geolocation
data is or is not the correct location. FixMyStreet would fail as a service if
the authorities it is reporting to cannot trust the location information it is
sending to be useful.








