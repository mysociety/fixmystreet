---
layout: page
title: FixMyStreet's surveys
author: dave
---

# FixMyStreet's surveys

<p class="lead">
  By default, four weeks after a user reports a problem, FixMyStreet sends an
  email inviting that user to complete a survey (which we also sometimes call a
  questionnaire). The survey is presented as a page on the site that asks the
  user about the current
  <a href="{{ "/glossary/#state" | relative_url }}" class="glossary__link">state</a>
  of the problem (for example, it may have been fixed), and lets them add an
  <a href="{{ "/glossary/#update" | relative_url }}" class="glossary__link">update</a>
  too.
</p> 
  
We recommend that you keep this feature enabled, because it gives you
useful data about the problems that have been reported on your site, and
an indication of the performance of the 
<a href="{{ "/glossary/#body" | relative_url }}" class="glossary__link">bodies</a>
that should be fixing them. Some users will report a problem and then won't
really think about it after that. We're happy with this, because it's how the
site is supposed to work &mdash; reporting a problem is easy and doesn't demand
any further interaction.

That's why sending a survey email a month later works well. It serves as a
reminder, and it helps ensure that the reports that have been fixed have their
states set accordingly.

Of course, it's possible that the problem has already been marked as fixed (or
indeed any other state). The questionnaire is an opportunity for the user who
reported the problem to confirm or change this.

The email contains a unique link to a page on the site, inviting the reporter
to set the state of the problem and, optionally, to add an update. Updates can
include photographs, so sometimes users add a picture to show the repair or
fix.

The survey link is authorised for the user who submitted the problem report,
because it's been sent directly to the email address they've registered with
your site. This means that the survey is easy for them to access and complete.

Each survey updates and collects data concerning a _single_ report. It's not
a questionnaire about the general performance of your site.

## Follow-up surveys

If the user doesn't confirm that the problem has been fixed, FixMyStreet will
offer to send another survey in another four weeks. That's an opt-in question:
the process will repeat with a new email and survey in four weeks' time, but
only because the user agreed to this.

## The survey email

The email that is sent out is made using the `questionnaire.txt` template. The
default is in `/templates/email/default/`. Of course, you should override this
in your own
<a href="{{ "/glossary/#cobrand" | relative_url }}" class="glossary__link">cobrand</a>
&mdash; see more about 
[customising email templates]({{ "/customising/templates/#emails" | relative_url }}).

The email message contains a link to the survey page that includes a token that
authenticates the user who submitted the report (this is possible because it is
sent directly to their own email address).

The basic wording of the email is shown below. We put more information in the
footer (such as links to the site and related social media), and include the
text of the report that was submitted.

    Hello Anne Example,

    4 weeks ago, you reported a problem using FixMyStreet.

    The details of that report are at the end of this email.

    To keep FixMyStreet up to date and relevant, we'd appreciate it if
    you could follow the link below and fill in our short questionnaire
    updating the status of your problem:

       https://fixmystreet.example.com/Q/BJ6muiBaxLwuF7kwqo

    All the best,

    The FixMyStreet team
    ...

## What's in the survey?

The default survey invites the user to make an
<a href="{{ "/glossary/#update" | relative_url }}" class="glossary__link">update</a>
to the problem report:

   * change the <a href="{{ "/glossary/#state" | relative_url }}" class="glossary__link">state</a>
     &mdash; for example, to _fixed_, because it's been fixed (unless it was
     already in that state)
   * add a comment or description (optional)
   * upload a photo (also optional)

It also asks:

   * have you ever reported a problem to the body before?
   * (if the problem has not been marked as fixed) do you want to receive
     another survey email in four weeks' time?

The default template is defined in `/templates/web/default/questionnaire/*`,
with the questions in `index`. As with all templates, you can override
these with your own cobrand &mdash; for details, see
[customising templates]({{ "/customising/templates/#emails" | relative_url }}).

Note that if you want to collect other data in your survey, you'll need to
update the source code to handle this.

If the user changes the state of a problem that is currently _fixed_ to
something else, that is, they effectively re-open the problem, then the update
comment is not optional.

## How to see the results

You can see the collected results of surveys by logging in as an
<a href="{{ "/glossary/#administrator" | relative_url }}" class="glossary__link">administrator</a>
and visiting `admin/questionnaire` in the admin (or click on **Survey** in the
admin menu bar).

The survey results are shown as total counts and percentages. They provide the
following numbers:

### First-timers, or repeat users?

* _Reported before / Not reported before_
  <br>
  How many reports were made by users who had reported a problem before, and
  how many are first-time reporters?
  
We collect that information because it's a key indicator of how much impact a
platform like FixMyStreet is having. Is it encouraging and enabling people who
had not previously engaged with authorities to do so?

### How did the state change in the surveys?

* _Old state_
  <br>
  The state the problem was in when the user did the survey (remember that
  anyone, including the body or the user themselves, may have set the state
  already, before the survey was sent).

* _New state_
  <br>
  What state did they change it to?

* _Total_
  <br>
  This is the number of problem reports (also expressed as a percentage) that
  users have moved from the old state to the new state in their surveys.
  
How complex these results are will depend to some extent on the states that
your site allows. For example, if you've allowed
<a href="{{ "/glossary/#staff-user" | relative_url }}" class="glossary__link">staff users</a>
to have more detailed states to choose from than the public (such as "fixed
&mdash; council", or "in&nbsp;progress"), then you'll have more combinations to
deal with. See the [admin manual]({{ "/running/admin_manual/" | relative_url }}) for more
information about the report states that are available to staff users.

## How to turn questionnaire-sending off

By default, your site will send out questionnaires.

If you don't want your site to send out questionnaires, you need to override
the `send_questionnaires` method in the `Cobrand` module for your cobrand.
Surveys will never be sent if that method returns false. This is not controlled
by a configuration setting, so you do need to edit the Perl code &mdash; see
more about [changing the Cobrand module](customising/cobrand-module).

