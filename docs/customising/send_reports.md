---
layout: page
title: How FixMyStreet sends reports
author: dave
---

# How FixMyStreet sends reports

<p class="lead">
After a user submits a problem, FixMyStreet sends a <strong>problem report</strong> to the body responsible for fixing it. Typically, reports
are sent by email. It's possible to override the content of the report (the email template), or even the way in which it is sent.
</p>

## Check and send every few minutes

FixMyStreet runs a task called `send-reports` at regular intervals (by default this is every 5 minutes) that finds all new reports and sends them on to the bodies responsible.

To change the frequency of this job, change the `crontab` settings. Suggested values are in `conf/crontab.example`. You'll need to understand the Unix crontab syntax to make sense of that file. Be careful editing it if you are not familiar with crontab, because the syntax is very precise.

## Which reports are sent?

The `send-reports` task finds all *confirmed* reports that have not yet been sent, and runs through each one, determines which body (or bodies) it needs to go to, and sends them.

Reports are usually confirmed by the user clicking on the confirmation link in the email that was sent to them.

Alternatively, a report is marked as confirmed if it was created after the user logged in either with a password or by clicking on a confirmation link in an email (a browser session).

It's possible to add a user who repeatedly sends abusive reports to the abuse list -- reports created by such users are automatically hidden and are never sent. To add a user to the abuse list, in the admin go to any report they have created and click on **Ban email address**.

## Where does the report get sent?

FixMyStreet uses the location of the problem to identify which bodies may be responsible for fixing it, and then decides which contact (typically an email address) to use) based on the chosen category. This is described in more detail on the page about [FMS and MapIt](/customising/fms_and_mapit).

The actual contacts can be added, changed, or deleted via the admin. See [managing bodies and contacts](/running/bodies_and_contacts) for details.

## What gets sent?

If the contact is an email (which is the simplest and most common form of report sending) then the email template `templates/email/default/submit.txt` is used. This is a simple text-based email with a simple preamble and all the useful details from the report.

If you want to change this (which is a good idea) add your own `submit.txt` to `templates/email/your-cobrand-name/`.

## How to know if a report has been sent

The public view of the report shows this: it says how long after creation the
report was sent (for example, "Sent to South Borsetshire District Council two
minutes later"). Alternatively, find the report in `admin/reports` -- the
report will show a "when sent" date if the `send-reports` task has processed
it successfully.

## Alternatives to email

Although by default FixMyStreet sends reports by email, it's possible to inject reports *directly* into some
bodies' databases or back-end systems. This is usually much better than using email because it's more convenient
for the staff working at the receiving end. See
[more about integration]({{ "/customising/integration/" | relative_url }}) for details.

## Technical investigation

If you have access to your server and are comfortable using the command line, 
you can manually run the `send-reports` script. Normally you never need to do
this because, as described above, FixMyStreet runs it using `crontab` every
five minutes. But if you're investigating why reports aren't sending, you can
run the script manually. The `send-reports` script normally runs silently, that
is, it produces no output (this is to prevent cron sending a logging email
every time it runs, including the times there are no reports to send anyway).
But if you want to see what's going on, you can use these options:

   * the `--verbose` option prints out a summary of reports that did not get
     sent. Incidentally, this option is useful even in
     <a href="{{ "/glossary/#production" | relative_url }}" class="glossary__link">production</a>,
     because it causes cron to send a logging email containing this summary of
     failed-to-send reports if anything goes wrong.

   * the `--debug` option prints out detail about the sending process as
     it is being attempted. As the script loops through each of the reports
     it's trying to send, it will try to print out useful information for each
     attempt. It also makes it clear if the script hasn't found *any* reports
     to send.

For example, to run `send-reports` with debugging output, do:

    bin/send-reports --debug

