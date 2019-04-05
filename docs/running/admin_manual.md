---
layout: page
title: FixMyStreet Administrator's Manual
author: dave
---


# Administrator's Manual

<p class="lead">What is it like running a FixMyStreet site? This guide
explains what you can expect, and the types of problem that you might
encounter. It includes examples of how mySociety manages their own site, <a
href="https://www.fixmystreet.com/">fixmystreet.com</a>.</p>

## About this document

We'll be giving suggestions and examples of problems from our experience in
the UK. But there is more than one way to solve issues, and you may well find
that your own solutions work best.

We hope that you will contribute to this document with your own ideas and
feedback. You can do this by [contacting us](https://www.mysociety.org/contact/)
directly, or joining the mailing list.

The [FixMyStreet mailing list](/community) is a great place to share ideas or
ask questions. Everyone on there has either built, or is building, a
FixMyStreet site, so they have real-life knowledge and are keen to help.

It's a friendly community, and we recommend that you join in and ask as many
questions as you need to.

## Other helpful documents

* **Before** you decide to run FixMyStreet, you should read the
  ["Can we fix it?" DIY Guide]({{ "/The-FixMyStreet-Platform-DIY-Guide-v1.1.pdf" | relative_url }}).

* If you are hosting FixMyStreet yourself, you **must** read the [installation
  instructions](/install) first. Once you've done that, you'll probably need
  the information about [customising your site](/customising) too.

* This guide is just one of several useful pages for <a
  href="{{ "/glossary/#administrator" | relative_url }}" class="glossary__link">administrators</a> in the
  section about [running FixMyStreet](/running). This document is the most
  general, so is a good place to start.

## Find your administrator

Every FixMyStreet site needs an <a href="{{ "/glossary/#administrator" | relative_url }}"
class="glossary__link">administrator</a>. Even when the site is running smoothly,
your users will need help, and there will be regular administrative tasks to
perform. So, sooner rather than later, you will need to think about who will
be responsible.

<div class="attention-box info">
  If you're just starting on your FixMyStreet project, it's possible that you
  have not found an administrator yet, or that you didn't realise you needed
  one. Don't worry! Look through this document to see why you need one, and
  what sort of tasks they'll be doing.
</div>

## Who do I need?

The team who sets up the site and those who keep it running day-to-day might
(or might not) be the same people.

**To set up a new installation**, we recommend you have at least **one
developer** and **one administrator** who can work on the site.

At the beginning you'll be quite busy. You'll be doing a lot of things, like
customising your site, collecting the email addresses your users' <a
href="{{ "/glossary/#report" | relative_url }}" class="glossary__link">problem reports</a> will be sent to,
and perhaps [promoting your project]({{ "/running/promotion/" | relative_url }}).

**Once your site is up and running**, you can manage with just **one
administrator**.

The administrator deals with problems and questions from users - we call this
'user support'. He or she will also answer questions from the bodies you send
your reports to.

Each day, the administrator of mySociety's UK FixMyStreet site spends, on
average, between 15 minutes and an hour on user support.

Ideally, your administrator will work every day, as there may be urgent
requests (see "Types of tasks", below). But if you cannot manage this, a
couple of sessions a week will be sufficient.

Our administrator usually checks support emails twice a day, in the morning
and at lunchtime. This breaks the work into very short blocks, but also
ensures that she can deal with any urgent problems promptly.

## The administration pages ("admin")

### Security

By default, the administration pages &mdash; the "admin" &mdash; can be found at
`/admin`. These pages must be secured against public access.

We strongly recommend you access your admin over a secure connection, such as
HTTPS. This means that everything that goes between your computer and the
server is encrypted, so can't easily be intercepted.

It's also a good idea to allow access to admin only from your own, trusted IP
addresses.

Both of these precautions require system configuration (that is, they depend
on settings outside FixMyStreet). If you're running an Apache webserver, you
can do this using `htauth` &mdash; see [the Apache htauth
documentation](http://httpd.apache.org/docs/current/mod/mod_authn_file.html).
If you're using an external hosting service, their technical support staff may
be willing set this up for you if you can't do it yourself.

It's very important that you do secure your admin: so if you really do have
problems setting this up, [get in touch](/community/) and we'll try to help.

### Contents

The Admin interface is divided into the following sections. You can access
them by clicking on the link at the top of any admin page:

* **Summary page** <br/> The summary page shows the number of live <a
  href="{{ "/glossary/#report" | relative_url }}" class="glossary__link">reports</a>, <a
  href="{{ "/glossary/#update" | relative_url }}" class="glossary__link">updates</a>, <a
  href="{{ "/glossary/#alert" | relative_url }}" class="glossary__link">alerts</a>, sent
  <a href="{{ "/glossary/#survey" | relative_url }}" class="glossary__link">questionnaires</a> and
  bodies' <a href="{{ "/glossary/#contact" | relative_url }}" class="glossary__link">contacts</a>.

  <p>
    This page is useful when the media ask how many reports your site has
    processed. You can also use it to motivate your team, or to prove yourself
    to official bodies.
  </p>

* **Bodies** <br/> <a href="{{ "/glossary/#body" | relative_url }}" class="glossary__link">Bodies</a> are the
  authorities that your site sends reports to. Each body has its own page in
  the admin, listing the categories of problem that they accept (eg, potholes,
  street lights, etc) and the email address associated with the category.

  <p>
    Bodies sometimes change their email addresses, and dealing with this is a
    regular task for an administrator. You can add or edit bodies from these
    pages. You can also add or edit their <a href="{{ "/glossary/#category" | relative_url }}"
    class="glossary__link">categories</a> and <a href="{{ "/glossary/#contact" | relative_url }}"
    class="glossary__link">contact</a> email addresses. Bodies are associated with
    one or more <a href="{{ "/glossary/#area" | relative_url }}" class="glossary__link">areas</a>. <a
    href="{{ "/running/bodies_and_contacts/" | relative_url }}">More information on bodies</a>.
  </p>

* **Reports** <br/> The reports page lets you search for, and edit <a
  href="{{ "/glossary/#report" | relative_url }}" class="glossary__link">problem reports</a> and updates.

  <p>
    You will need to do this often - for example, when a user has emailed to
    complain about a report, or to ask you to check if the report has been
    sent.
  </p>
  <p>
    You can search by the user's name, email address, or a word or phrase from
    the report.
  </p>
  <p>
    If your database is very large &mdash; like the UK FixMyStreet, which has many
    thousands of reports &mdash; some searches may be a little slow. But if you
    know the ID of the report, you can tell FixMyStreet to find it directly,
    using <code>id:</code> first. The ID is in the URL of the live report: for
    example, on our site, we can find
    <code>https://www.fixmystreet.com/report/391267</code> by searching for
    <code>id:391267</code>.
  </p>

* **Timeline** <br/> The timeline is a log of FixMyStreet activity: report
  updates, status changes, and so on.

* **Survey** <br/> By default, FixMyStreet sends out <a
  href="{{ "/glossary/#survey" | relative_url }}" class="glossary__link">surveys</a> (also called
  questionnaires) to users four weeks after they reported a problem.

  <p>
    We use these surveys to collect data on the performance of the bodies. The
    survey page shows statistics based on the responses, which again can be
    useful for the media, or for research when you are looking at how
    effective your site has been.
  </p>
  <p>
    If you don't want your FixMyStreet site to send out surveys, you can
    switch off this behaviour in a <a
    href="{{ "/customising/cobrand-module/" | relative_url }}">cobrand module</a>.
  </p>

* **Users** <br/> You can [manage users](/running/users) from this section.
  For example you can edit a <a href="{{ "/glossary/#user-account" | relative_url }}">user's</a>
  email address, or <a href="{{ "/glossary/#flagged" | relative_url }}" class="glossary__link">flag</a> or
  <a href="{{ "/glossary/#abuse-list" | relative_url }}" class="glossary__link">ban</a> or abusive one.

  <p>
    Each user has an individual page in the admin, and it is sometimes quicker
    to search for a user than a report, if they have contacted you by email
    and have not mentioned which report they are talking about. Each user's
    page lists all their activity on the site.
  </p>
  <p>
    By default, any staff users (those that belong to a body) are listed on
    this page.
  </p>

* **Flagged** <br/> You can <a href="{{ "/glossary/#flag" | relative_url }}"
  class="glossary__link">flag</a> any report or user. This does not <a
  href="{{ "/glossary/#abuse-list" | relative_url }}" class="glossary__link">ban</a> the user or delete the
  report - it is just a way of marking a person or a situation as potentially
  troublesome. Note that you can only flag a report or user from the report
  or page.

  <p>
    This can be useful if your team has more than one <a
    href="{{ "/glossary/#administrator" | relative_url }}" class="glossary__link">administrator</a>. <a
    href="{{ "/running/users/" | relative_url }}">More information about managing users</a>.
  </p>

* **Stats** <br/> The stats page lets you analyse the number and types of <a
  href="{{ "/glossary/#report" | relative_url }}" class="glossary__link">report</a> over a particular date
  range. Optionally, you can restrict it to report on a single <a
  href="{{ "/glossary/#body" | relative_url }}" class="glossary__link">body</a>.

  <p>
    You might use this if you want to know how many reports have been sent
    within, for example, the last three months, or how many reports have been
    sent to a specific body since launch.
  </p>

* **Configuration** <br/> This page shows you a summary of the live
  configuration information for your site.
 
<a name="report-states"></a>

## Report states

A <a href="{{ "/glossary/#report" | relative_url }}" class="glossary__link">problem report</a> can be in
one of these <a href="{{ "/glossary/#state" | relative_url }}" class="glossary__link">states</a>:

<dl class="reveal-on-click" data-reveal-noun="report states">
  <dt>
    Unconfirmed
  </dt>
  <dd>
    <p>
      Until FixMyStreet is certain that the report's creator is genuine, its
      state remains <em>unconfirmed</em>. Unconfirmed reports do not appear on
      the website. A report is confirmed (and its state becomes <em>open</em>)
      when:
    </p>
    <ul>
      <li>
        its creator clicks on the link in FixMyStreet's confirmation email, or
      </li>
      <li>
        its creator was already logged in when the report was created, or
      </li>
      <li>
        an <a href="{{ "/glossary/#administrator" | relative_url }}"
        class="glossary__link">administrator</a> confirms it (by searching in
        <strong>Reports</strong> and changing the state by clicking
        <strong>edit</strong>).
      </li>
    </ul>
  </dd>
  <dt>
    Open
  </dt>
  <dd>
    <p>
      An <em>open</em> report is one that has not been fixed or closed. This
      generally means that the body has not yet attended to the problem. Also,
      this implies that the report is not <em>unconfirmed</em> (see above). <a
      href="{{ "/glossary/#staff-user" | relative_url }}" class="glossary__link">Staff users</a> can set
      problems to have alternative "open" states, which by default are:
    </p>
    <ul>
      <li>
        <em>investigating</em>
      </li>
      <li>
        <em>in progress</em>
      </li>
      <li>
        <em>action scheduled</em>
      </li>
    </ul>
    <p>This list of states can be edited in the admin interface.</p>
  </dd>
  <dt>
    Fixed
  </dt>
  <dd>
    <p>
      <em>Fixed</em> reports are marked in two possible ways:
    </p>
    <ul>
      <li>
        <em>fixed - user</em>
        <br>
        If a user marks them as fixed in an <a href="{{ "/glossary/#update" | relative_url }}"
        class="glossary__link">update</a>, or (for the report creator only) as part
        of the process of answering the 4-week <a href="{{ "/glossary/#survey" | relative_url }}"
        class="glossary__link">survey</a>.
      </li>
      <li>
        <em>fixed - council</em>
        <br>
        If updated by a <a href="{{ "/glossary/#staff-user" | relative_url }}" class="glossary__link">staff
        user</a> from the body responsible for that report.
      </li>
    </ul>
  </dd>
  <dt>
    Closed
  </dt>
  <dd>
    <p>
      A <a href="{{ "/glossary/#staff-user" | relative_url }}" class="glossary__link">staff user</a>
      associated with the report's body (or an <a
      href="{{ "/glossary/#administrator" | relative_url }}" class="glossary__link">administrator</a>) can
      mark a report as <em>closed</em> without declaring it to be
      <em>fixed</em>. Possible states by default are:
    </p>
    <ul>
      <li><em>no further action</em></li>
      <li><em>not responsible</em></li>
      <li><em>duplicate</em></li>
      <li><em>internal referral</em></li>
    </ul>
    <p>This list of states can also be edited in the admin interface.</p>
  </dd>
  <dt>
    Hidden
  </dt>
  <dd>
    <p>
      Reports can be hidden by an <a href="{{ "/glossary/#administrator" | relative_url }}"
      class="glossary__link">administrator</a>, or (if the <a
      href="{{ "/glossary/cobrand" | relative_url }}" class="glossary__link">cobrand</a> allows it) by a <a
      href="{{ "/glossary/#staff-user" | relative_url }}" class="glossary__link">staff user</a> associated
      with the body to which it was sent.
    </p>
    <p>
      Hiding a report means that it is unpublished, and can no longer be seen
      on the live site - usually because it is abusive or inappropriate.
      Hidden reports remain in the database, and can be republished if
      necessary.
    </p>
    <p>
      Remember that a hidden report will probably have been sent to the <a
      href="{{ "/glossary/#body" | relative_url }}" class="glossary__link">body</a> responsible (so it can
      still be fixed) &mdash; hiding a report simply prevents it being displayed.
    </p>
  </dd>
</dl>

## Types of Tasks

There are two main types of tasks for FixMyStreet <a
href="{{ "/glossary/#administrator" | relative_url }}" class="glossary__link">administrators</a>.

* **Maintenance** tasks can be fixed through the FixMyStreet admin interface.

* **User support** is generally handled by email.

The most common maintenance tasks are described below, based on our own
experience with the UK site.

<dl class="reveal-on-click" data-reveal-noun="types of task">
  <dt>
    Bounce-backs / dead email addresses from the bodies
  </dt>
  <dd>
    <p>
      When FixMyStreet sends a <a href="{{ "/glossary/#report" | relative_url }}"
      class="glossary__link">problem report</a> to the <a href="{{ "/glossary/#body" | relative_url }}"
      class="glossary__link">body</a> responsible, sometimes that email bounces
      back. This usually means the <a href="{{ "/glossary/#contact" | relative_url }}"
      class="glossary__link">contact</a> email address you've got for that body (and
      that <a href="{{ "/glossary/#category" | relative_url }}" class="glossary__link">category</a>) is
      wrong, or has changed.
    </p>
    <p>
      You can tell which report &mdash; and which body and category &mdash;
      caused the problem by looking at the returned email.
    </p>
    <p>
      Then, in admin, go to <strong>Bodies</strong> and look at the contact
      email addresses for that body. Check that the email address looks
      correct (for example, if there are several, see if they adhere to the
      same format).
    </p>
    <p>
      If everything looks OK, you can check online to see if you can find a
      better address. Otherwise, you'll need to contact the body and confirm
      the correct email address to use.
    </p>
    <p>
      Sometimes the email address may be correct, but there's another problem
      which prevents it receiving the email (such as a full mailbox). Be sure
      to check the error message that the mail server returned in the
      bounce-back message.
    </p>
    <p>
      When you have found the correct email address, make sure that you
      re-send the report which bounced. And if you can't find an address, you
      should contact the user to let them know that unfortunately you couldn't
      deliver their report.
    </p>
  </dd>
  <dt>
    Removing personal data from reports or making them anonymous
  </dt>
  <dd>
    <p>
      Sometimes people include personal details such as their address in their
      report. Or they forget to tick the box to make their reports anonymous.
      Sometimes a user decides to make their report anonymous after they have
      submitted it.
    </p>
    <p>
      In all cases, you can edit the report in admin by going to
      <strong>Reports</strong>. Find the report you want, then click on
      <strong>Edit</strong>.
    </p>
    <p>
      Remove the details that should not be shown (we recommend replacing them
      with something like “[address removed, but sent to
      <em>name-of-body</em>]”).
    </p>
    <p>
      If necessary, you can mark the report as anonymous with the yes/no
      selection box.
    </p>
    <p>
      Be sure to save your changes (click <strong>submit changes</strong>)
      when you've finished editing.
    </p>
  </dd>
  <dt>
    Removing reports when users say they didn't realise their report would be
    public
  </dt>
  <dd>
    <p>
      Occasionally people who are reporting issues don't understand that the
      site is public, and they don't want their name associated with the
      report.
    </p>
    <p>
      In the UK, mySociety's first step is to anonymise the report. If the
      user insists that the report must be removed, you can hide it instead -
      then let your user know that you've made the changes they asked for.
    </p>
    <p>
      We're generally happy to hide such reports because we don't want to
      anger our users. And although this removes them from the website, the
      problem report will still have been sent to the body responsible.
    </p>
   </dd>
  <dt>
    Removing inappropriate reports
  </dt>
  <dd>
    <p>
      There is a 'report abuse' link at the foot of every report, which any
      user can use to alert you to a report. You will sometimes receive emails
      to tell you that a report or update is inappropriate or potentially
      libellous.
    </p>
    <p>
      UK law states that we can be held legally responsible for the content,
      but only if we have been made aware of it. You should make yourself
      familiar with the law in your own jurisdiction, and how it may affect
      your liability.
    </p>
    <p>
      In most cases, if a report has been brought to your attention, you
      should hide it - unless there is clearly nothing wrong with it.
    </p>
    <p>
      Abuse report emails contain the admin URL of the problem report, so you
      can click on it and change its state to <em>hidden</em>.
    </p>
    <p>
      It's generally a good idea to then tell the user who reported the abuse
      that you have removed it. You may also wish to contact the abusive site
      member to explain why their report has been removed.
    </p>
  </dd>
  <dt>
    Users who send a report to the support email address
  </dt>
  <dd>
    <p>
      On the UK FixMyStreet site we are careful to explain that we are an
      independent organisation, and we do not fix street problems ourselves.
    </p>
    <p>
      But we still frequently receive email that should have gone to a local
      council. In other words, people click on the 'support' button and submit
      a report, rather than going through the normal report-making process on
      the site.
    </p>
    <p>
      We send a carefully-worded response like this:
    </p>
    <div class="correspondence">
      <p>
        You have emailed the technical support team behind FixMyStreet, when
        it looks as though you intended your message to go to your council.
        FixMyStreet is an independent website through which you can contact
        any council in the UK.
      </p>
      <p>
        If you wish to report a problem please visit www.fixmystreet.com and
        enter a postcode or street name near where the problem is located. You
        will then be invited to click on a map to show where the problem is
        occurring.
      </p>
      <p>
        Your message is below so that you can copy and paste it into the form.
        *Note that all messages appear on our website, as well as going to the
        council*.
      </p>
      <p>
        If you are able to take the time to let us know why you emailed this
        address rather than file a report on the site, it would really help us
        to make the process clearer for future users.
      </p>
    </div>
    <p>
      You are welcome to adapt this text to your own site's needs.
    </p>
  </dd>
  <dt>
    Manually changing users' email addresses </dt>
  <dd>
    <p>
      Users cannot change their email addresses themselves. In admin, go to
      <strong>Users</strong>, find the user (search by their name or the old
      email address) and edit the email address to be the new one.
    </p>
  </dd>
</dl>

## Common user support queries

Here is a list of the most common user support queries we get on the UK
FixMyStreet site.

<dl class="reveal-on-click" data-reveal-noun="support queries">
  <dt>
    A body wants to know what email addresses you have on file
  </dt>
  <dd>
    <p>
      In the UK, it's common for each body to have multiple <a
      href="{{ "/glossary/#contact" | relative_url }}" class="glossary__link">contacts</a> (usually email
      addresses) &mdash; for more information, see <a
      href="{{ "/running/bodies_and_contacts/" | relative_url }}">About bodies and contacts</a>. Your
      site may be the same.
    </p>
    <p>
      Often, a body will make contact to ask where your reports are being
      sent. Perhaps they are changing addresses, or they are puzzled because
      they can see reports on the site but don't know who is receiving them.
    </p>
    <p>
      It's worth being friendly and helpful - if you have a good relationship
      with the body, they will inform you when their contact details change,
      and are more likely to treat your users' reports with respect.
    </p>
    <p>
      Note that you can quickly copy and paste all email addresses for a body
      by clicking on <strong>text only version</strong> on that body's page.
    </p>
  </dd>
  <dt>
    Body replies to you, not the user
  </dt>
  <dd>
    <p>
      This can happen if the body has set up their auto-response system
      incorrectly, for example, the body has used your support email address
      instead of responding directly to a user.
    </p>
    <p>
      Forward the email to the user. Let the body know you've had to do this,
      and point out the correct email address to use (FixMyStreet sends its
      emails with the reply-to field set to that of the user who reported the
      problem).
    </p>
  </dd>
  <dt>
    Press enquiries or data/statistic enquiries
  </dt>
  <dd>
    <p>
     Currently any requests for data or statistics that cannot be seen on the
     admin summary page have to be handled by a developer, by making SQL
     queries directly on the database.
    </p>
    <p>
      <a href="{{ "/glossary#staff-user" | relative_url }}" class="glossary__link">Staff users</a> can see
      the <a href="{{ "/glossary#dashboard" | relative_url }}" class="glossary__link">dashboard</a> for
      their own body by going to <code>/dashboard</code> when they are logged
      into the public site. If they don't have a staff user set up, offer to
      do this for them: see <a href="{{ "/running/users/" | relative_url }}">managing users</a>.
    </p>
  </dd>
  <dt>
    User needs help on how to make a report on the site
  </dt>
  <dd>
    <p>
      Sometimes you may get an email from a user saying the site isn't
      working, or they can't use it. Remember that your users come from all
      sectors of society, including the very elderly or those who are not used
      to computers.
    </p>
    <p>
      You will often need to write back to clarify the problem. Ask for as
      much detail as possible about their operating system and browser - in
      simple words - and ask them to describe the issue precisely.
    </p>
    <p>
      Often there is no problem with the site (although you should never be
      certain of that until you have checked). Maybe the user has not seen the
      submit button, or doesn't understand how to upload a photo, or has not
      understood how the site works for some other reason.
    </p>
    <p>
      Step-by-step instructions by email can almost always help.
    </p>
  </dd>
  <dt>
    User does not receive report confirmation email
  </dt>
  <dd>
    <p>
      <strong>This is almost always because the automated confirmation email
      has gone into the user's spam folder</strong>.
    </p>
    <p>
      Ask the user to look in their spam folder (and mark email coming from
      your domain as "not spam" so future emails don't get caught in the same
      way). If they still can't find it, you can confirm the report from
      within admin (see <a href="#report-states">Report States</a>, above).
    </p>
    <p>
      If you're running FixMyStreet on your own server, you (or your system
      administrator) can check your outgoing email logs to confirm that the
      user's mail server accepted delivery from your end.
    </p>
  </dd>
  <dt>
    User wants to know how to change their password
  </dt>
  <dd>
    <p>
      Users don't need a password to use FixMyStreet - they can click the link
      in the confirmation email instead. But if a user makes a large number of
      reports, it makes sense to have a password. If they are logged into the
      site, they do not have to confirm reports via the email link.
    </p>
    <p>
      Any user can set a new password at any time.
    </p>
    <p>
      We send this response to requests to change the password:
    </p>
    <div class="correspondence">
      When you next create a problem report or update, simply choose the
      option that says 'No, let me confirm by email'. You will be able to
      create a new password at that point. This will send you a confirmation
      email. Clicking the link in that email will update your password for
      you.
      <p>
        Alternatively, you can visit https://www.fixmystreet.com/auth and do
        the same (that is, choose the 'no' option and input your new
        password).
      </p>
    </div>
    <p>
      Of course, make sure you change the URL in that message to match your
      own installation.
    </p>
    <p>
      Note that there's no need to provide the old password, because the
      change requires the user to click on the confirmation link in the email.
    </p>
  </dd>
  <dt>
    User wants to edit their problem report
  </dt>
  <dd>
    <p>
      A user cannot change their message once they have submitted it &mdash; and
      remember that the report will have already been sent to the body
      responsible.
    </p>
    <p>
      However, if there is a good case for changing the post on the website,
      you can do this in the admin. Go to <strong>Reports</strong>, find the
      report you want, and click on <strong>Edit</strong>.
    </p>
    <p>
      Be sure to save your changes (click <strong>submit changes</strong>)
      when you've finished editing.
    </p>
  </dd>
  <dt>
    User requests a new feature or reports a bug
  </dt>
  <dd>
    <p>
      You can log feature requests and bug reports by submitting (or, if you
      prefer, by asking your developer to submit) an issue to the public
      FixMyStreet <a
      href="https://github.com/mysociety/fixmystreet/issues">GitHub
      repository</a>.
    </p>
    <p>
      Always search the issues first to check that it hasn't already been
      raised. If it has, you can add a comment noting that it's been requested
      again by another user.
    </p>
    <p>
      When users in the UK contact FixMyStreet support with a request for a
      new feature, we also reply to thank the person for taking an interest in
      the site. We really do change FixMyStreet in response to user feedback!
    </p>
  </dd>
  <dt>
    User can't find a relevant category for their problem
  </dt>
  <dd>
    <p>
      FixMyStreet constructs the list of <a href="{{ "/glossary/#category" | relative_url }}"
      class="glossary__link">categories</a> of report (for example, "Pothole" or
      "Graffiti") based on what services the body (or bodies) <em>in that <a
      href="{{ "/glossary/#area" | relative_url }}" class="glossary__link">area</a></em> provide. See <a
      href="{{ "/running/bodies_and_contacts/" | relative_url }}">Managing bodies and contacts</a> to
      see how this works.
    </p>
    <p>
      This has two important consequences: it means the list of categories may
      be different depending on <em>where</em> the user is reporting the
      problem, and it means that sometimes the category the user wants is not
      available.
    </p>
    <p>
      When you add categories for the bodies in your FixMyStreet installation,
      you should consider adding an "Other" category &mdash; provided, of course,
      that the body has a general email address for such requests to go to.
    </p>
    <p>
      Be careful, though, because if multiple bodies at the same location
      offer a category called "Other", FixMyStreet &mdash; correctly &mdash; will send
      such reports to all of them.
    </p>
    <p>
      To understand more about about this, see <a
      href="{{ "/running/bodies_and_contacts/" | relative_url }}">Managing bodies and contacts</a>.
    </p>
  </dd>
  <dt>
    Report has gone to wrong body
  </dt>
  <dd>
    <p>
     Sometimes a report is sent to the wrong body because the user has placed
     the pin wrongly, putting the report in a different administrative
     jurisdiction. Or perhaps the user has chosen the wrong category, routing
     the report to a different body.
    </p>
    <p>
      mySociety replies to the user asking them to resubmit the report with
      the pin more correctly positioned, or the right category selected.
    </p>
    <p>
      This problem may indicate that the boundary data you are using is either
      incorrect, or not accurate enough &mdash; for more information, see <a
      href="{{ "/customising/fms_and_mapit/" | relative_url }}">How FixMyStreet uses MapIt</a>.
    </p>
  </dd>
  <dt>
    User wants to unsubscribe from local alerts
  </dt>
  <dd>
    <p>
      Alerts are sent as emails: there's an unsubscribe link at the foot of
      each one, so usually you just need to point this out politely.
      <!-- TODO should be able to unsubscribe them in the admin -->
    </p>
  </dd>
  <dt>
    User just wants to send praise or thanks
  </dt>
  <dd>
    <p>
      It's nice to hear! mySociety's FixMyStreet administrator shares these
      with the team and will always write back to the user to thank them.
    </p>
  </dd>
  <dt>
    The maps are out of date because there's been new development in the
    user's area
  </dt>
  <dd>
    <p>
      Your FixMyStreet installation will normally be using maps from an
      external source &mdash; by default this is <a href="{{ "/glossary/#openstreetmap" | relative_url }}"
      class="glossary__link">OpenStreetMap</a>.
    </p>
    <p>
      For the UK FixMyStreet, we use maps produced by the government (Ordnance
      Survey), and we advise our users to contact them with any errors. Other
      installations use custom maps too, so the remedy to this problem will be
      different in different locations.
    </p>
    <p>
      OpenStreetMap is an editable project, so it is possible to encourage
      users &mdash; or your own team &mdash; to update the map information. It will take
      a while for the map tiles to update, so these changes might not appear
      on your own site immediately.
    </p>
  </dd>
</dl>
<div class="attention-box helpful-hint">
  <p>
    A tip from Myf, who looks after the UK FixMyStreet site:
  </p>
  <p>
    “User Support got much quicker for me once I assembled a spreadsheet with
    the responses to all our most common questions and enquiries - it took a
    while to put together (because I was learning the ropes) but once it was
    done, I could just copy and paste, and I can now send the majority of
    replies off with just a few modifications.
  </p>
  <p>
    I'd really recommend that approach. As well as saving me time, it means I
    can hand user support over to others when needed, for example, when I go
    on holiday.”
  </p>
</div>

## How the site may be abused

Any website that accepts input from the public can attract abuse - but our
experience from the UK FixMyStreet site is that it's rare. The following
section discusses some issues you should be aware of.

### Obscene, rude or illegal material

People may occasionally post rude, defamatory or vexatious material. Here's
our official policy from the UK FixMyStreet site:

<div class="correspondence">
  FixMyStreet does not moderate reports before they appear on the site, and we
  are not responsible for the content or accuracy of material submitted by our
  users. We will remove any problem report containing inappropriate details
  upon being informed, a process known as reactive moderation. Many sites
  utilise this process, for example the BBC, as explained here:
  <a href="http://news.bbc.co.uk/1/hi/help/4180404.stm">http://news.bbc.co.uk/1/hi/help/4180404.stm</a>.
</div>

If a user gets in touch to complain about a report, it is sometimes because
they are offended or distressed by the content. Sometimes a report will
contain their name and address, and may be a top result when they search for
themselves on Google.

Understandably, they may be upset or angry. Once you have made any necessary
modifications to the report - or removed it completely - you should reply
politely and calmly. Tell the user what action you have taken, and let them
know about the site policy.

It is important to make it clear that the views our users post on FixMyStreet
are not the views of mySociety.

We don't perform proactive moderation (that is, checking everything *before*
publishing it on the site) for two reasons.

First, for the quantity of traffic we handle, it would be impractical. Second,
doing so would make us liable for the content under UK law. You will need to
check what the law is in your country, and how best to deal with issues such
as these.

The FixMyStreet code *does* support moderation-before-publication, although
this is currently only enabled in the Zurich cobrand.

### Spam reports

Many sites which publish user-generated content suffer from spam - that is,
automated bots posting messages.

On the UK FixMyStreet site, we do not receive many spam reports. Currently it
is almost entirely prevented by the confirmation link process.

However, we cannot say that this will always be true, and you will need to be
aware of this possibility.

If your site does start to suffer from spam, please share your experience with
mySociety and the community, because it's likely that solutions and responses
to the problem will be useful to everyone.

### Silly or time-wasting reports

Occasionally a user will post a nonsensical report, just for amusement.

Although such things generally seem harmless, remember that, in the age of
social media, a link to amusing content can spread fast.

In the UK, we've had one memorable case where the comedy report was publicised
in many media, and was eventually reported on the BBC website.

You may be thinking that it's great publicity for your site, but remember that
these reports do get sent through to the bodies responsible. FixMyStreet's
role as a credible source of reports may be undermined if this happens too
often.

Also, unfortunately, once one silly report has been made, it often gives other
users the idea to do the same.

Consequently, on the UK FixMyStreet site we have a policy of hiding such
reports as soon as we are aware of them, to prevent other users being
encouraged to copy the behaviour.

### Abuse: conclusion

In practice, "problem users" are judged on a one-by-one basis. You can flag a
user or a report as problematic, and then, if they transgress again, you can
ban their email address by adding it to the "abuse list". See [managing
users](/running/users/) for details.

It's a good idea to agree on a policy for dealing with abuse issues, and to
make sure all your administrators know what it is.

## Software updates

The FixMyStreet platform is under constant development. This means that new
features and improvements are made from time to time: we announce new releases
(which have version numbers) on the [fixmystreet.org blog](/blog), and on
the mailing list (see [more about staying in touch](/community)).

Updating is a technical activity, and you'll need to log into the server's
"command shell" to do it &mdash; so ask your developer to do this for you if you're
not confident.

If you've installed FixMyStreet as a git repository cloned from
[github.com/mysociety/fixmystreet](https://github.com/mysociety/fixmystreet) &mdash;
which will be the case if you've followed our installation instructions &mdash;
your developer should find it easy to update. Make sure they know that
sometimes these updates do require changes to the database schema too (look
for new migration files in the `db` directory). Always check the version
release notes (for example, on the blog) because we'll mention such things
there.

## And finally...

We wish you all the best with your FixMyStreet problem reporting site.

If you have any questions, don't hesitate to <a href="{{ "/community/" |
relative_url }}">contact us</a> and we'll get back to you as soon as possible
with an answer.
