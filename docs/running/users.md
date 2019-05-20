---
layout: page
title: Managing users in FixMyStreet
author: dave
---

# Managing users in FixMyStreet

<p class="lead">Members of the public who just want to report a problem often
don't expect or want to create an account. They choose confirmation-by-email
instead of logging in. Nonetheless FixMyStreet does offer admin capability for
managing your users.</p>

Regular users or staff can benefit from having an account -- they can set a
password to make future visits to the site easier. But this is not mandatory.

## How users are normally created

You do not need to create users before the system goes live. Public user
accounts are created during normal operation. In fact, **it's common to
*never* create a user in the admin** because the FixMyStreet site takes care
of it for you..

A new user record is created when an email confirmation link is clicked
(unless, of course, the user already exists with that email address). This
process is automatic and, unless the user subsequently sets a password, most
people don't consider their interaction with FixMyStreet as being
account-based. For example, around 70% of the users who have reported a
problem on the UK's [fixmystreet.com](https://www.fixmystreet.com) site did not
use a password (this effectively means: they did not consider creating an
account).

## Manually creating a new account (in the admin)

Sometimes it's helpful to manually create a new account for someone --
typically this is for a staff user (see below).

Firstly if you don't have admin access, you'll want to run the
`bin/createsuperuser` script to create a user that has access to the admin.

You can create a new user account explicitly using the admin. Go to
`admin/users` and fill in the form. A confirmation email is not sent to the
email address if you create a new account in this way.

## Users' passwords

If a user sets a password, they can use it to login on future visits (instead
of using a confirmation link in an email). We don't make this mandatory.

### Setting or changing a password

Any user can set a password by going to `/auth` and entering a password. A
confirmation link is emailed in the same way as usual. Clicking on the link
sets the password for future use, and also confirms the current session.

Changing a password is the same as setting it. A confirmation link is sent to
the email, which they must click on before the change is made. There's no need
for the user to enter their *old* password when changing an existing one,
because the authorisation is still sent as an email confirmation link anyway.

You cannot change a user's password within the admin pages.

### Storing passwords

Passwords are hashed (one-way encryption) when they are stored in the
database. You cannot recover a user's password; if they forget it, they must
set a new one.

## Changing a user's email address

You can change a user's email address or name by finding their record at
`admin/users` and changing the entry there. Email addresses must be unique.

## When users misbehave

Occasionally a user repeatedly posts inappropriate or vexations posts. In our
experience this is much less common than most people expect. However, it's a
problem that arises from time to time. As administrator of your installation,
there are two actions you can take. Firstly, you can *flag* a user, which is
just a way of marking them (in the admin) so you and other administrators know
to keep an eye on them. Secondly, you can add their email address to the
"abuse table".

### Flagging a user

Flagging a user has no practical effect, other than to mark the user as one
whose actions need to be checked. You can see the flagged users by going to
`admin/flagged`.

### Blocking a user's email address

If a user persistently abuses your installation, by repeatedly creating
inappropriate or false reports, for example, you can ban them. If a user
creates a report while they are banned, they are automatically hidden and not
sent to the bodies (see [how FixMyStreet sends
reports](/customising/send_reports)).

To add a user to the 'abuse table', go to the admin pages and find any report
they have created. Click on **ban email address**.

Users are not automatically notified that they have been banned.

### How you know when a user is misbehaving

The default behaviour of FixMyStreet is **not** to moderate reports before
they are displayed (although at least one cobrand does support this). Instead,
every report displayed on the FixMyStreet site has a "report abuse" link, so
anyone can notify you if inappropriate content has been posted. You can hide a
report (go to `/admin/reports` to find it, and mark it as hidden) and
optionally flag or ban its creator. On some installations, staff users can
hide reports themselves. Hiding a report usually occurs *after* it's already
been sent to the body responsible (you're simply hiding it from view on the
FixMyStreet website).

## Staff user accounts (associated with a body)

You can mark any FixMyStreet user as belonging to a body. This marks them as a
"staff user" for that body. Staff users have extra privileges *which only apply
to problem reports under the jurisdiction of the body to which the use
belongs*. Permissions can be grouped into custom roles, and these roles and
individual permissions can be set on a per-user basis.

To set (or revoke) staff user status, choose **Users** in the admin, and enter
the email or name. (It's also possible to access a user via the reports they
have made). Choose the appropriate body from the **Body** dropdown. Normal
(not staff) users have no body associated. Then you can assign roles or permissions
to that user, depending upon what they require access to.

For full details of what staff accounts can do, please see the
dedicated [staff user](../staff/) page.

<a name="sessions"> </a>

## How FixMyStreet user sessions work

*The following information about sessions is here in case you need to
understand how it works. For normal operation, you don't need to worry about
it.*

By default, FixMyStreet uses email confirmation links, text confirmation codes,
or Facebook/Twitter login tokens, to check that the user is a genuine person,
with access to the email address/phone number they have provided. Even if
Facebook/Twitter are used, the site still performs email confirmation.

So FixMyStreet uses the email address or phone number as the key piece of
information when identifying a user. For email authentication, it sends a
confirmation link -- with a unique token within it -- to the specified email
address when an unidentified user performs a task that requires authentication,
such as submitting a report, or changing their password. For phone
authentication, it sends a confirmation code by text.

Clicking on a valid email confirmation link, or entering a text confirmation
code, not only confirms the action it was created for (for example, the report
is marked as *confirmed*, or the password is changed), but also starts a user
session. This means that, for the remainder of the session, other such actions
do not trigger further email confirmations. This is an nonintrusive way of
authenticating report submissions without explicitly using usernames, or
accounts, and is a deliberate part of FixMyStreet's design.

It *is* nonetheless possible to set a password, and log into FixMyStreet using
the email address as the identifier. Regular users, of course, use this
mechanism. When this happens, a user session is created when they log in.

A **sign out** link is shown on a user's account page once a user session has
begun. Clicking on it ends the session. User sessions are browser sessions:
they automatically expire when the user's browser shuts down.
