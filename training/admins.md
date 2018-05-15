---
layout: page
title: FixMyStreet training - administrators
author: dave
---


Training notes for new administrators
=============================

<p class="lead">
  These notes may serve as a basis for training people new to the FixMyStreet
  platform. They might be helpful if you&rsquo;re setting up a new site or team.
</p>
<div class="attention-box helpful-hint">
  <p>
    Basic training notes like these are available for
    <br>
    <a href="{{ "/training/citizens" | relative_url }}">citizens</a>,
    <a href="{{ "/training/staff" | relative_url }}">staff</a>, and
    <a href="{{ "/training/admins" | relative_url }}">administrators</a>.
  </p>
  <p>
    Refer to the <a href="{{ "/overview" | relative_url }}">full documentation</a>
    for more detailed information!
  </p>
</div>

Remember that every FixMyStreet installation is different, and can both
look and behave differently, depending on how it has been 
[customised]({{ "/customising/" | relative_url }}).

<!-- magically present as slideshow, slides split on h2 or h3 -->
<a name class="play-as-slideshow"></a>

---

## Admin accounts

* **admin accounts are usually _completely separate_ from staff accounts**

* a _staff user_ logs into the front-end web site

* an _administrator_ normally logs into the back-end

We encourage you to run the admin over an encrypted connection (that is,
over `https`).


##  How to log in

You can log into the FixMyStreet admin using the username and password provided.

###  Using HTAuth

If your browser asks you to enter your username and password in a browser
dialogue box (that is, it's not part of the website), you're using HTAuth. 

With HTAuth, how you logout will depend on your browser. Some browsers
automatically log you out when you quit the browser.

Don't access the admin on a public machine using this mechanism unless you
know how to log out.

## Understanding how the site works

A key thing is that citizen users do not need to know _who_ to send their
report to.

FixMyStreet works this out by using:

* **the precise _location_** (pin on the map) ...combined with...

* **the _category_ of the problem**

These two things determine:

* **which _body_ is responsible, and hence which _contact_ to send the**
  **report to**


## Or to look at it the other way round

When a user clicks on the map to report a problem...

* the drop-down menu of _categories_ that the user sees
  only contains categories with contacts belonging to bodies
  operating in that area

<div class="attention-box info">
  <p>
    So users cannot send problem reports to a body...
  </p>
  <ul>
    <li>
      for a problem that's not within that body's admin boundary
    </li>
    <li>
      with a category of problem that the body isn't responsbile for
    </li>
  </ul>
</div>

##  There might be lots of categories!

![example showing many categories]({{ "/assets/img/training/fms-many-categories.png" | relative_url }})

## Getting help in the admin

* there are lots of hints in the admin

* click on <span class="admin-help">**?**</span> orange question marks to
  see them

## Working with bodies

Click on **Bodies** in the admin (at the top of the admin section)
to list all the bodies in your system. 

* **click on each body's name to see and edit the details**

![example showing many categories]({{ "/assets/img/training/admin-bodies.png" | relative_url }})


## Configuring bodies and contacts

You can add new bodies in the admin. Click on **Bodies** -- the form for
adding a new body is underneath the list of existing bodies.
The key things you need to provide:

* **the name of the body**
  <br>
  as it will appear to the public

* **the administrative boundary**
  <br>
  that this body covers (usually just one, but sometimes many, for example, islands)

* **contact addresses** (usually emails)
  <br>
  for specific **categories** of problem

## Add a body

![example showing many categories]({{ "/assets/img/training/admin-add-a-body.png" | relative_url }})


### You must specify an area

You must indicate the body's admin boundary because if a problem is
not within the body's area, it won't be reported to it.

<div class="attention-box warning">
  <strong>a body with no area will not receive any problem reports</strong>
  <br>
  this is why you must specify an area
</div>

We can help with admin boundary data, or providing alternatives
(such as a the special area "everywhere").
 
### Where do "areas" come from?

FixMyStreet uses a separate service called MapIt to serve area data.

This is described in detail in the documentation, and must be configured when
your FixMyStreet site is first set up.

The actual geometric data (polygons describing the boundary of each area) may
come from the OpenStreetMap project, from your own government's official data,
or be custom. Ask us if you need help.

## Adding contacts and categories

You need to add contacts to each body.

<div class="attention-box warning">
  <strong>a body with no contacts will not receive any problem reports</strong>
  <br>
  this is why you must add at least one contact
</div>

* usually contacts are email addresses

* each contact is for a _category_ of problem

* you can have lots of categories even if some or all use the _same_ email address

### Adding a contact

![add a contact/category]({{ "/assets/img/training/admin-add-contact.png" | relative_url }})


### Confirm your contacts!

When you enter a contact, if you can confirm it's valid, tick the __Confirmed__
checkbox:

* reports are only sent to confirmed contacts

<div class="attention-box warning">
  <strong>a body with no confirmed contacts will not receive any problem reports</strong>
  <br>
  this is why you must confirm the contacts if you know they are correct
</div>


We used this mechanism when we started FixMyStreet in the UK -- we crowdsourced
the contacts from the public, so an admin needed to confirm they were valid
before we could use them.

### Simple example of a body and its area and contacts

If there's a single authority responsible for burst water
pipes and public standpipes in the whole country, and it has one email
address:

* _body:_ National Water Company
* _area:_ the country's border
* _categories & contacts_:
  <br>burst water pipe &rarr; help@examplewater.com
  <br>blocked standpipe &rarr; help@examplewater.com

## Alternatives to email

If the body has a back-end system that supports it, FixMyStreet _can_
deliver problem reports directly.

* Open311 -- an open standard for this kind of submission

* admin already supports Open311

* a single body can support more than one kind of "send method" -- some
  categories using email addresses, and others direct submission

See the full documentation for details about "back-end integration".

## Deleting a body or a contact

Normally you don't need to do this often.

* to delete a body, edit it and tick the checkbox **Flag as deleted**

* to delete a contact (or category), edit it and tick the checkbox **Deleted**

In both cases, this treats it as deleted, but does not remove it from the database.

This is mainly because existing reports may well depend on the (old)
body or the (old) category.

## Deleting records from the database

* **you cannot delete bodies or categories from the database**

* you can mark them as _deleted_, which behaves in a similar way

If you really need to delete something (a training example body), you
can't do it through the admin. If you're not sure, or you don't have
access to your site's database, ask us for help!

## Administering reports

You can access all the report data from the admin. 
For example, as an administrator, you can:

* search for reports on keyword or id
* find all reports submitted by a particular user
* change the report wording as displayed on the site
* see the history of a report
* hide reports

## Finding a report

Click on **Reports** -- there's a search box at the top.

* if you know the report's number (id), search for `id:1234`
  <br>
  a report's id is shown as the number in its URL:
  <br>
  `fixmystreet.com/report/1234`
  
* search by keyword

* find user or body, and scroll

### Searching reports

![search reports]({{ "/assets/img/training/admin-search-reports.png" | relative_url }})

## What the different timestamps mean

There are four date stamps listed when you edit a report.
You can't change them because they are recorded by the system
but it can be helpful to understand them.

* **Created** -- when the problem report was entered on the website

* **Confirmed** -- when the creator clicked the email confirmation link
  <br>
  If a report was very late in being sent, check this timestamp: remember that
  a report is _never sent until it has been confirmed_
  <br>
  Also, if a user is logged in when they create a report, it's automatically
  confirmed

* **Sent** -- when the report was sent to the body
  <br>
  normally this is up to 5 minutes after the report was confirmed

* **Last update** -- when the record was last changed in the admin


## Editing reports

Remember, to edit a report, normally you click on **Reports** and then
find the report you want by searching, and then clicking on **Edit**
in list of results.

These are the things you can do when you edit a report:

* change the report's wording
* change the report's state
* hide the whole report
* hide the name of the person who submitted it

Remember to click the **Submit changes** button when you have finished
editing a report.

## Editing the wording of a report

* **edit the report**

* **text is free to edit in a text area**

* we recommend you **always mark text you've changed**

For example, if you remove someone's telephone number, replace it with

`[telephone number redacted]`

...or something similar. It's good to make it clear that:

1. something was removed
2. why you removed it

## Changing a report's state

* **edit the report**

* **select the new state from the drop-down list**

If you want to confirm a report (for example, a user has told you they deleted
their confirmation email before clicking on the link), you can mark an
_unconfirmed_ report as _open_. This simulates them clicking on the
confirmation link themselves.

## Hiding a report

<div class="attention-box info">
  Note that staff users can hide reports belonging to the body they represent,
  so typically you don't need to do this as an administrator.
</div>

* **edit the report**

* **change the state to _Hidden: hidden_**

(There are other kinds of _Hidden_ state, but you don't normally need them.)

Remember, hiding a report does not prevent it being sent. It just prevents
it being displayed on the website.

## Hiding the name of the report's creator

* **edit the report**

* **tick the checkbox labelled _Anonymous_**

## You can edit updates too

When you edit a report, any updates on that report are listed at the bottom
of the page. You can click **Edit** next to any of those to edit them.

* **you can change similar things in updates as you can reports:**

* change the wording in the update
* change the state the update sets the report to
* hide the name of the person who submitted the update

## When did a report get sent?

You can see this on the public site:

![sent yet?]({{ "/assets/img/training/mmi-18-show-when-sent.png" | relative_url }})

..but it's also shown as the "Sent" field if you look at the report in the admin.

* **the report has not been sent yet** if there's no "Sent to..." sentence 

* **the "send reports" job normally runs every 5 minutes**
  <br>
  so it's normal for a report to not go immediately when it is submitted

## Resending a report

If a report fails to get delivered, you can schedule it to be sent again.

* **to resend a report, edit it and click _Resend report_**
  <br>
  again, this can take up to five minutes before it's handled

## Managing users

To access the users in the admin, click **Users**. The page only
list _staff users_ by default. To see other users, use the search box
to search across email or name.

![show user]({{ "/assets/img/training/admin-users.png" | relative_url }})

## Editing a user

![edit user]({{ "/assets/img/training/admin-edit-user.png" | relative_url }})

### Change a user's name or email address

* **edit a user by finding them in the list of users and clicking _Edit_**

* (if you click on their email address in the list of search results, you
  get a list of all the reports and updates they've made)

* note that changing the user's name here doesn't change the name that
  was recorded with each report that they made before

## Creating a new user

The **Add user** form is underneath the search box and the list of staff users
when you click **Users**.

<div class="attention-box info">
  Note that it's unusual to make a normal user this way because, if they need
  to, any user can make their own account by signing in on the website.
</div>

* make sure the user has access to the email address you enter
  <br>
  check that you've spelled the email address exactly!

* creating a new user in this way means they will _not_ be emailed
  a notification email

* a normal (not staff) user has _"No body"_ as their body

## Make a staff user

* a staff user is simply a user account that's linked to a body

* they have some special powers over problem reports that were
  submitted to the body they are linked to
  
* **edit (or create) the user and choose the right body**

* normal (not staff) users have _"No body"_ as their body

## Flagging reports or users

* **flagging just marks the user or the report for attention**
  <br>
  so other administrators know to keep an eye on their activity

* it has no other effect

* if you want to ban a user, add them to the abuse list

### Flagged reports and users

![flagged things]({{ "/assets/img/training/admin-flagged-reports-users.png" | relative_url }})

## Banning a user: the abuse list

In addition to flagging a user, you can also add them to the
"abuse list" (that's a list of users who have abused their right
to have access to your site).

* **a user who's on the "abuse list" cannot use the site**

* **ban a user by clicking on "BAN EMAIL ADDRESS"**
  <br>
  when you are **editing a _report_ or _update_** they submitted
  
![ban a user]({{ "/assets/img/training/admin-ban-a-user.png" | relative_url }})

## Getting statistics

![getting stats]({{ "/assets/img/training/admin-stats-enter-dates.png" | relative_url }})

## Example of statistics

![output stats]({{ "/assets/img/training/admin-stats.png" | relative_url }})

## Other administration tasks

Remember to check the full documentation on 
[fixmystreet.org](https://fixmystreet.org).

If you need help, email us or ask for advice on the (public) FixMyStreet
mailing list.






