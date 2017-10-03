---
layout: page
title: Staff users in FixMyStreet
author: matthew
---

# Staff users in FixMyStreet

<p class="lead">Privileged accounts with access to management features.</p>

Staff users are a middle rung of account, inbetween normal users of the site
and superusers with full access to everything. They are associated with a
particular body, and can have access to different features, depending upon the
permissions granted to them. All their abilities only apply to reports made
to the body with which they are associated; all staff users have access to all
report states, not just open/fixed.

## Moderation

Staff users with this permission can moderate reports - editing the text of any
report or update, hiding abusive reports or updates, and making reports
anonymous.

## Edit reports

This gives the staff user access to the admin's "report edit" screen, letting
them fully access and edit any aspect of the reports.

## Inspect reports

Alternatively, you can give a staff user access to a front-end **report
'inspect' view**, which lets a user edit a report's category, state, location,
and other aspects of the report. If the category change moves the report to a
different body, it will be re-sent. Alternatively, a user can be given *only*
category edit or priority edit permission. Here is a screenshot of the top of
an inspect form view:

<img src="/assets/posts/report-inspect.png" alt="The inspect form lets you change category, state, report location, and so on.">

## Shortlist

<img class="l" src="https://cloud.githubusercontent.com/assets/739624/19122469/7fa927ba-8b22-11e6-8193-ef20d9ce496e.png" alt="">
A user with the shortlist permission gains a shortlist button on each report;
clicking this adds the report to your own personal shortlist of reports, which
you can view in a section of Your Account. This may be useful for an
'inspector' type of admin user, who wishes to compile the day's list of
reports before going out and investigating them. You can also see if a report
is on someone else's shortlist, and take it off them if you need to.

Reports added to a shortlist are cached offline and will be available
even if there is no internet access, which is very useful when you're out in the field.
<br style="clear:both">

## Report as another user/ body / anonymous

This permission gives a user the ability to create a report or update on behalf
of a body, or as another user, or totally anonymously. We envisage this being
useful in a body's contact centre, where they receive a report over a phone and
enter it into FixMyStreet as that user. Below is a short animation showing this
in action on the Oxfordshire cobrand of FixMyStreet.com:

![Show an example of the create as another in action](https://cloud.githubusercontent.com/assets/739624/17371098/9a55c806-5996-11e6-9602-cf1cf58f8cdb.gif)

There is also a "View body contribute details" permission which lets a user
see e.g. which staff user left a 'report as body' report.

## Edit users / Edit user permissions / Grant admin access

<div class="r" style="max-height:12em; overflow:auto;">
<img src="/assets/posts/admin-user-permissions.png" alt="">
</div>

These permissions give a user access to edit other users within the same body,
edit their permissions, or make/revoke other users' staff access.

You can associate a user with a list of categories, which e.g. pre-selects
those categories when the user visits the All Reports page.

## Edit problem categories

This lets a user edit the categories that normal users to make reports, and
where those categories go.

## Edit response templates

You can create and edit templates associated with your body, or with a
particular category in that body, and then when leaving an update you can
select one of these templates to allow easy updating of reports.

## Edit response priorities

This allows you to set a list of different priorities for a body, or again for
a particular category in a body, letting you note different priorities for
different reports.
