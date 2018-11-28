---
layout: page
title: Email bounces
---

# Handling email bounces

<p class="lead">
Sometimes an email sent from FixMyStreet bounces, perhaps because the contact
address for the responsible body is no longer correct. In order for your site
administrator to notice this, you can configure your system to use the
<code>handlemail</code> script.
</p>

## What `handlemail` does

Emails sent to a body when a report is created use something called VERP.
Basically this means that if the email bounces, it will be returned to a unique
address which includes the report ID, so we can figure out which report needs
to be re-sent and which contact address needs to be updated. Alerts use VERP
return paths as well, so we can unsubscribe an email address from further alerts.

All email sent to one of these VERP addresses should be handled by the
`handlemail` script. In addition to this, `handlemail` can also handle email
sent to the `DO_NOT_REPLY_EMAIL` address.

The list below describes what `handlemail` will do with these emails.

1. If an actual email (not a bounce) to the DO-NOT-REPLY address:

    1. If it looks like an out-of-office message, do nothing.
    1. Send an automatic reply (as a bounce) back to that email saying it is an
       unmonitored account (using the `reply-autoresponse` template)

1. If an actual email (not a bounce) to a VERP address (report submission/alert
   email):

    1. If a reply to an alert email and not out-of-office, forward to the
       contact email (defaults to `CONTACT_EMAIL`).
    1. If a reply to a report email, forward on to the report creator

1. If a bounce message to the DO-NOT-REPLY address, ignore it.

1. If a bounce message to a VERP address:

    1. If it looks like a permanent bounce (5xx error but not 5.2.2 mailbox
       full), unsubscribe the alert (alert bounce), or forward on to
       the contact email (report bounce).
    1. Otherwise, if it looks like an out-of-office, treat as an actual email
       (step 2)
    1. Or if unparseable, forward on to the contact email.
    1. Otherwise, ignore the bounce.

## Configuring `handlemail`

The `handlemail` script should be run by the same user that runs the FixMyStreet
web service (typically user fms). To configure this, add a line like this to
that user's .forward file:

```
"|/var/www/fixmystreet/bin/handlemail"
```

The .forward file should be created in the fms user's home directory. Include
the quotes (`"`) and leading pipe (`|`) character, which specify that the email
should be handled by a program.

Just make sure to set the path to where you have your clone of the fixmystreet
 repository. You can also specify a cobrand:

```
"|/var/www/fixmystreet/bin/handlemail --cobrand=moon"
```

The reply-autoresponse template used for emails sent to the DO-NOT-REPLY address
 will then use the template for that cobrand.

By default `handlemail` uses `CONTACT_EMAIL` as its contact email, but you can
override this by specifying an email in the command line with the `--bouncemgr`
argument.

If the fms user is running cron jobs, error messages from those jobs are
typically sent to the fms user. To avoid sending those to `handlemail`, you
might want to update the crontab for the fms user by adding a `MAILTO`
directive, such as:

```
MAILTO=support@fixmymoon.org
```

Finally, you'll need to make sure that email sent to the VERP addresses and to
the DO-NOT-REPLY address is routed to the fms user. This will be different
depending on how you've configured your email server, but if you're using
Postfix you can do this with a virtual alias table.

### Postfix example configuration

In your main.cf (typically /etc/postfix/main.cf), add a regexp table to the
virtual_alias_map setting:

```
virtual_alias_maps = regexp:/etc/postfix/virtual.regexp
```

Then create the virtual.regexp file and add a rule for routing any email
starting with fms- to the fms user:

```
/^fms-/ fms
```
Before this file can be used by postfix it needs to be compiled:

```
postmap /etc/postfix/virtual.regexp
```
The Postfix service needs to be restarted since main.cf was modified.

Finally, set the `DO_NOT_REPLY_EMAIL` setting in conf/general.yml to
`fms-DO-NOT-REPLY@\<yourdomain\>` so those emails also match the rule.
