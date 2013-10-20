---
layout: default
title: FixMyStreet Administrator's Manual
author: dave
---

# Administrator's Manual

<p class="lead">This guide will give you a broad overview of what it takes to
administer a FixMyStreet site and the types problems that you might face when
running it. It also includes some examples of how the administrator for the
UK's <a href="http://www.fixmystreet.com">fixmystreet.com</a> site deals with
these issues.</p>

## About this document

This manual contains examples of suggestions and problems from our UK
experience. This is not a definitive guide on how to solve issues and you may
well find that your own solutions work best.

Please feel free to contribute and discuss what could be added to help
this. We have a lovely community of re-users that have all been through the
set-up and administration of one of these sites. They’re a great resource for
answers and you should feel free to join in or ask for help.

## Who is the administrator?

The team who sets up the site and the team who keeps it running day-to-day
might not be the same people. Administrative work and user support is a
regular requirement and you will need to think about who could be responsible
for it.

<div class="attention-box info"> 
If you're just starting with your FixMyStreet site, it’s possible that you
have not got an administrator yet, or that you didn’t realise you needed one.
Don't worry! Look through this document to see the kind of things you need to
think about when finding someone.
</div>

**To set up a new installation**, we recommend you have at least **one
developer** and **one administrator** who can work on the site.

At the beginning it’s likely these roles would be quite labour intensive as
you customise your site, collect the email addresses and work on promoting your
project.

**Once your site is up and running**, and being used every day, you can
manage with just **one administrator**.

For mySociety’s UK FixMyStreet site, which has been running since 2007, we
need a maximum of one hour per day to manage the user support and site
administration. User support will naturally take slightly longer after
weekends than towards the end of the week. In the UK, the support emails are
typically checked twice daily, in the morning and at lunchtime, so the actual
workload becomes very light.

## The administration pages ("admin")

By default, the admininstration pages -- the "admin" -- can be found at
`/admin`. These pages must be secured against public access.

We strongly recommend you access your admin over a secure connection, such as
HTTPS (this means that everything that goes between your computer and the
server is encrypted, so can't easily be intercepted). Furthermore, it's a good
idea to restrict access to only those IP addresses from which you know you
will be accessing it. Both these things require system configuration (that is,
it's outside FixMyStreet itself) so we can't describe how to do this here.

The admin has the following sections:

* **Summary page** - The summary page shows the number of live reports,
  updates, confirmed/unconfirmed alerts, sent questionnaires and bodies'
  contacts.

* **Bodies** - You can add or edit <a href="/glossary/#body" class="glossary">bodies</a> and
  their categories and contacts. Bodies are associated with one or more 
  <a href="/glossary/#area" class="glossary">areas</a>.
  [More information on bodies](/running/bodies_and_contacts).

* **Reports** - The reports page lets you search and edit 
  <a href="/glossary/#report" class="glossary">problem reports</a> and updates
  in the system. If your database is very large -- for example, the UK
  FixMyStreet has tens of thousands of records -- some searches may be a
  little slow. If you know the ID of a particular report, use "id:12345".
  <!-- TODO or hack the URL? -->

* **Timeline** - The timeline is a log of FixMyStreet activity: report
  updates, status changes, and so on.

* **Survey** - By default, FixMyStreet sends out surveys (also
  called questionnaires) four weeks after they reported a problem. These
  ask the user whether or not their problem was fixed, and we use these to
  collect data on the performance of the bodies (in the UK, the councils).
  The survey page shows statistics based on the responses to the surveys
  that have been sent out. If you’re not sending out surveys this
  section will not be populated.
  <!-- TODO check configuration of surveys -->

* **Users** - You can [manage users](/running/users), including adding new ones
  or banning abusive ones. By default, any staff users (those that belong to
  a body) are listed on this page, but you can use the search to find others.

* **Flagged** - You can flag any report or user. This simply marks it for 
  attention, typically because it is potentially troublesome. This is especially
  useful if your team has more than one administrator.
  [More information about managing users](/running/users).

* **Stats** - The stats page lets you generate a statistics report of problem
  reports over a particular date range (and, optionally, a body).

## Report states

A <a href="/glossary/#report">problem report</a> can be in one of these states:

* **Unconfirmed** If FixMyStreet is not certain that the report's creator
  is genuine, it state remains *unconfirmed*. Unconfirmed reports do
  *not* appear on the website. A report is confirmed if:
  
   * its creator clicks on the confirmation email that was sent to them as
     soon as the report was created
   * its creator was already logged in when the report was created
   * an administrator finds it in the admin, and explicitly confirms it

* **Open** An *open* report has not be fixed or closed. This generally
  means the problem has not yet been attended to. Furthermore, the user who
  created it has clicked on the confirmation link that was emailed to them,
  or else was logged in when they created it. Staff users can set problems
  to have alternative "open" states:

   * investigating 
   * in progress 
   * action scheduled

* **Fixed** Fixed reports can be marked "fixed - user" if marked fixed
  by a public user, or "fixed - council" if marked fixed by a staff user
  from the body responsible for that report.

* **Closed** - a user associated with a body or an admin user can mark
  reports as "unable to fix", "not responsible", "duplicate", or "internal
  referral"

* **Other** - hidden (by admin user, inappropriate/abusive/etc), unconfirmed (new
  report not shown as email address not confirmed)

## Types of Tasks 

Broadly speaking, there are two types of tasks for FixMyStreet administrators.
**Maintenance** tasks are tasks that can be fixed through the online content
management system of FixMyStreet. **User support** is generally handled using
email contact with the users.

There's not much to do to keep the site running: the beauty of FixMyStreet is
that all the hard work is done for you by the website.

For the UK site the most common maintenance tasks are described below:  

<dl class="reveal-on-click">
  <dt>
    Bounce-backs / dead email addresses from the bodies
  </dt>
  <dd>
    <p>
      When FixMyStreet sends a problem report to the body responsible, sometimes that
      email bounces back. This usually means the email address you've got for that
      body (and that category) is wrong, or has changed. 
    </p>
    <p>
      You can tell which report -- and hence which body and category -- caused the
      problem by looking at the returned email. Then, in the admin, go to **Bodies**
      and look at the contacts for that body. Check that the email address looks correct
      (for example, if there are several, see if they look similar). If everything looks
      OK, you'll need to contact the body in question and confirm the correct email
      address to use. It’s likely that this will take up a little time, because you
      can't route such problems to the body until you've found a correct email address.
    </p>
    <p>
      Sometimes the email address may be correct, but there's another problem which prevents 
      it receiving the email (such as a full mailbox). Be sure to check the error message
      that the mail server returned in the bounce-back message.
    </p>
  </dd>
  <dt>
    Removing personal data from reports or making them anonymous
  </dt>
  <dd>
    Sometimes someone will write their name and address into the description
    field on the website. Or they will forget to tick the box to make their
    reports anonymous. Sometimes people decide they want to make their reports
    anonymous after they have submitted it.
  </dd>
<!-- TODO check that you can mark existing report as anon in the admin interface -->
  <dt>
    Removing reports where users say they didn't realise it would be public
  </dt>
  <dd>
    <p>
      Occasionally people who are reporting issues don’t understand that the site is
      public, and for whatever reason they don’t want their name associated with the
      report.
    </p>
    <p>
      In the UK, mySociety’s first step is to anonymise the report. If the user
      insists that the report has to be removed, you can hide it instead. We're
      generally happy to hide such reports because even though this removes them
      from the website, the problem report will still have been sent to the body
      responsible.
    </p>
    <p>
      If you hide a report, it’s generally a good idea to also let the user/reporter
      know once this has been done.
    </p>
  </dd>
  <dt>
    Removing reports that could potentially be libellous
  </dt>
  <dd>
    <p>
      There can also be cases where potentially libellous material has been drawn to
      your attention (there's a 'report abuse' link at the foot of every report,
      which any user can use to tell you about a bad report).
    </p>
    <p>
      In the UK, this is an issue because we can be held legally responsible for the 
      XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
    </p>
    <p>
      <!-- TODO remove this -->
      For example, a reporter could state that they believe people in house X on
      street Y are dealing drugs, because people come and go from the house all day
      long. As there is no hard evidence to back this up this report is libellous.
      (Of course you may be using the site to report drug dealers, this is an
      example of what could be libellous from the UK site, which doesn’t use
      FixMyStreet to report issues such as these). Libellous reports in the UK have
      to be removed and can be hidden in the admin interface, check with your local
      laws about what’s expected of you in your country. It’s generally a good idea
      to also let the user/reporter know once this has been done.
    </p>
  </dd>
  <dt>
    Correcting users who think you are the body to which the reports are sent
  </dt>
  <dd>
    <p>
      <!-- rewrite signposting -->
      There is a lot of "signposting" on the UK site to show who mySociety is and who
      the council is, but people will still email us with queries for the local
      councils. You may find that this happens when you are running your site as
      well. We direct these sorts of requests back to the local council, generally
      by sending a carefully worded response reminding the user who runs the site.
    </p>
    <p>
      mySociety’s response currently reads: 
    </p>
    <div class="correspondence">
      <p>
      “You have emailed the technical support team behind FixMyStreet, when it looks
      as though you intended your message to go to your council.
      </p>
      <p>
      If you wish to report a problem please visit http://fixmystreet.com/ and enter
      a postcode or street name near where the problem is located. You will then be
      invited to click on a map to show where the problem is occurring.
      </p>
      <p>
      Your message is below so that you can copy and paste it into the form. Note
      that all messages appear on our website, as well as going to the council. If
      you are able to take the time to let us know why you emailed this address
      rather than file a report on the site, it would really help us tighten things
      up and make the process clearer for future users."
      </p>
    </div>
  </dd>
  <dt>
    Manually changing users’ email addresses when requested
  </dt>
  <dd>
    <p>
      Users cannot change their email addresses themselves. Do this in the admin:
      go to **Users**, find the user required (search by old email address)
      and edit the email address to be the new one.
      <!-- TODO CHECK THIS -->
    </p>
  </dd>
</dl>

## Common user support queries

To help you anticipate the sort of support work you may need to do -- and
to help you do it -- here is a list of the most common user support queries
we get on the UK FixMyStreet site.

<dl class="reveal-on-click">
  <dt>
    Responding to councils who want to know what email addresses you have on file
  </dt>
  <dd>
    <p>
      In the UK, it's common for each body to have multiple contacts (usually email addresses)
-- for more information, see <a href="/running/bodies_and_contacts">About bodies and contacts</a>. 
It could be that your council is set up this way too.
    </p>
    <p>
      Keeping a good relationship with the council and having them ask what email
      addresses you have, hopefully because they want to update them before you have
      to ask if they are wrong, can help stop the email bounce back issue.
    </p>
  </dd>
  <dt>
    Forwarding emails from the council where they’ve replied to you, not the user
  </dt>
  <dd>
    <p>
      This can happen if the council has set up their auto-response system incorrectly, 
      for example, the council has used the mySociety helpline email instead of responding
      directly to a user.
    </p>
  </dd>
  <dt>  
    Responding to press enquiries or data/statistic enquiries 
  </dt>
  <dd>
    <p>
      A number of these requests come through. Currently any requests for data or
      statistics that cannot be seen on the admin dashboard have to be handled by a
      developer (by making SQL queries directly on the database).
    </p>
  </dd>
  <dt>
    Talking users through how to make a report on the site
  </dt>
  <dd>
    <p>
      Sometimes you may get an email from a user saying they can’t use the site.
      Often this is because they haven’t seen the submit button, or they can’t
      upload a photo, or a similar request. A quick step-by-step email can help
      solve this.
    </p>
  </dd>
  <dt>
    User not receiving report confirmation email 
  </dt>
  <dd>
    <p>
      Almost always this is due to the user's spam or junk filters intercepting the email
and placing it in their spam folder. Encourage them to look in their spam folder (and
maybe mark email coming from your domain as "not spam" so future emails don't get caught
in the same way).
    </p>
    <p>
      If you’re running FixMyStreet on your own server, you (or your system administrator)
      can check your outgoing email logs to confirm that the user's mail server accepted
      delivery from your end.
    </p>
  </dd>
  <dt>
    Users who say the site isn’t working 
  </dt>
  <dd>
    <p>
      You may not get any more information than this! You can write back with step-by-step
      instructions on how to use the site, which may solve the problem.
    </p>
  </dd>
  <dt>
    User wants to know how to change password
  </dt>
  <dd>
    <p>
      Many users use FixMyStreet without ever setting a password (because they
      clicked the confirmation link in the email instead). 
    </p>
    <p>
      However, any user can set a new password at any time, although most don't
      realise it.
    </p>
    <p>
      We sometimes send this response to requests to change the password: 
    </p>
    <div class="correspondence">

    “When you next create a problem report or update simply choose the option
    that says 'No, let me confirm by email'. You will be able to create a new
    password at that point. This will send you a confirmation email. Clicking
    the link in that email will update your password for you.

    Alternatively, you can visit http://www.fixmystreet.com/auth and do the
    same (that is, choose the 'no' option and input your new password).”

    </div>
    <p>
      Note that there's no need to provide the old password, because the change
requires the user to click on the confirmation link in the email anyway.
    </p>
    <p>
      Of course, make sure you change the URL to match your own installation.
    </p>
  </dd>
  <dt>
    User wants to edit their post
  </dt>
  <dd>
    <p>
      A user cannot change their message once they have submitted it -- and remember
      that the report will have already been sent to the body responsible. However,
      if there is a good case for changing the post on the website, you can do this
      in the admin.
    </p>
    <!-- can edit in the admin TODO -->
  </dd>
  <dt>
    User requests a new feature
  </dt>
  <dd>
    <p>
      You can deal with these by submitting (or, if you prefer, by asking your
developer to submit) the request as an issue in the public FixMyStreet 
<a href="http://github.com/mysociety/fixmystreet/issues">github repository</a>.
It’s best to search the issues to check that it hasn’t already been raised.
    </p>
    <p>
When users in the UK contact FixMyStreet support with a request for a new
feature, we forward the email to our developers for consideration, and reply
thanking the person for taking an interest in the site.
    </p>
  </dd>
  <dt>
    User can't find a relevant category for their problem 
  </dt>
  <dd>
    <p>
      On the UK site there's usually a category called "Other" in each body's
contact list. Because the drop-down menu that the user chooses from depends
on which categories are offered by the body (or bodies) responsible for that
location.
    </p>
    <p>
When you add categories for the bodies in your FixMyStreet installation, you
should consider adding an "Other" category -- provided, of course, that the
body you are associating it with will respond to such requests.
    </p>
    <p>
Be careful, though, because if multiple bodies at the same location offer a
category called "Other", FixMyStreet -- correctly -- will send such reports to
all of them.
    </p>
    <p>
      To understand more about about this, see 
      <a href="/running/bodies_and_contacts/">Managing bodies and contacts</a>.
    </p>
  </dd>
  <dt>
    Report has gone to wrong council 
  </dt>
  <dd>
    <p>
      This is normally because the user placed the pin on the wrong side of a
boundary on the map or selected the wrong problem category in FixMyStreet. In
this case mySociety normally replies to the user asking them to resubmit the
report with the pin more correctly positioned or the right category selected.
In some cases mySociety will send the reports to both councils asking them to
ignore the report if it is not relevant for them.
    </p>
    <p>
      This problem may indicate that the boundary data you are using is either 
incorrect, or not accurate enough -- for more information, see 
<a href="/customising/fms_and_mapit/">How FixMyStreet uses MapIt</a>.
    </p>
  </dd>
  <dt>
    User wants to unsubscribe from local alerts 
  </dt>
  <dd>
    <p>
      Alerts are sent as emails: there's an unsubscribe link at the foot of each one,
      so it's a matter of just pointing this out politely!
    </p>
  </dd>
  <dt>
    User just wants to send praise or thanks 
  </dt>
  <dd>
    <p>
    It’s nice to hear! Normally mySociety’s FixMyStreet admin shares these with the team
and writes back to the user to thank them.
    </p>
  </dd>
  <dt>
    The maps are out of date because there's been new development in the user's area
  </dt>
  <dd>
    <p>
    XXXXXXXXXXXXXXXXXXXXXXXX
There's an Ordnance Survey email address they can contact in the UK. If you’re
using this internationally it’s likely you’ll be using openstreetmap. This
means you would be able to log in as an openstreetmap user and change things
yourself. However these changes can take a little while to show. You’ll be
able to find more information on OpenStreetMap itself.
    </p>
  </dd>
</dl>

<div class="attention-box helpful-hint">
  <p>
    A tip from Myfanwy, who looks after the UK FixMyStreet site:
  </p>
  <p>
    “Things got much quicker for me once I assembled a spreadsheet with the
    responses to all our most common questions and enquiries - it took a while to
    assemble (because I was learning the ropes) but once it was done, I could just
    copy and paste and I can now send the majority of replies off with just a few
    modifications.
  </p>
  <p>
    I'd really recommend that approach. As well as saving me time, it means I can
    hand user support over to others when needed, for example, when I go on holiday.”
  </p>
</div>


## Some other things to consider

You may occasionally get people who misuse the site by posting rude, defamatory
or vexatious material. Here's our official response from the UK FixMyStreet site: 

<div class="correspondence">
  "FixMyStreet does not moderate reports before they appear on the site, and we
  are not responsible for the content or accuracy of material submitted by our
  users. We will remove any problem report containing inappropriate details upon
  being informed, a process known as reactive moderation. Many sites utilise
  this process, for example some of the BBC community areas as explained here:
  <a href="http://news.bbc.co.uk/1/hi/help/4180404.stm">http://news.bbc.co.uk/1/hi/help/4180404.stm</a>.
</div>

That lets people know from the first instance that the views found on
FixMyStreet are not the view of mySociety. We don’t perform proactive
moderation (that is, checking everything *before* publishing it on the site)
for two reasons. First, for the quantity of traffic we handle, this would be
impracticable. Second, doing so would make us liable for the content under UK
law. You will need to check what the laws are like in your country and how to
deal with issues such as these. The FixMyStreet code *does* support
moderation-before-publication, although this is currently only enabled in the
Zurich cobrand.

On the UK FixMyStreet site, we do not receive many spam reports. By this we
mean that there are no automated bots posting messages on the site. Currently
this is largely prevented by the need to confirm reports by clicking on the
emailed confirmation link. However, this is not to say that this will never
happen and you will need to be aware of this possibility. If you do start to
suffer from such behaviour, please do share your experience with mySociety and
the community, because it's likely that solutions and responses to the problem
will be useful to everyone.

Occasionally a user will use a site to report a nonsensical report, and share the
subsequent link, just for amusement. Although such things generally seem harmless,
remember that the link will probably be shared (in the UK, we've had one memorable
case where the report was publicised on the BBC) and ultimately you need to decide
if the potential publicity the site may be getting is being undermined by the 
suggestion that it allows silly or unhelpful reporting. Remember that these reports
do get sent through to the bodies responsible, and FixMyStreet's role as a credible
source of reports may be undermined if this happens too often.

Consequently, on the UK FixMyStreet site we have a policy of hiding such
reports as soon as we are aware of them, to prevent other users being
encouraged to copy the behaviour.

In practice, "problem users" are judged on a one-by-one basis. You can flag a user
or a report as problematic and then, if they transgress again, you can ban their email
address by adding it to the "abuse list".

## Software updates

The FixMyStreet platform is under constant development. This means that new features
and improvements are made from time to time: we announce new releases (which have version numbers)
on the [code.fixmystreet.com blog](/blog), and on the mailing list (see [more about
staying in touch](/community)). Updating is a technical activity, so ask your developer
to do this for you.

If you've installed FixMyStreet as a git repository cloned from
[github.com/mysociety/fixmystreet](http://github.com/mysociety/fixmystreet)
(which will be the case if you've followed our recommended installation instructions),
your developer should find it easy to update. Make sure they know that sometimes these updates do 
require changes to the database schema too (look for new migration files in the `db` directory). 
 
## And finally...

We wish you all the best with your FixMyStreet problem reporting site. If you're
running an installation outside the UK and have any questions, don’t hesitate to email
international@mysociety.org and we’ll get back to you as soon as possible with
an answer.




