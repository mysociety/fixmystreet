---
layout: page
title: Login/authenticaton
author: matthew
---

# Customising login/authentication

<p class="lead">
  This page describes the different possible forms of logging in.
</p>

By default, FixMyStreet uses email or password authentication. Confirmation
emails are sent containing a link, clicking which confirms the account (and
optionally sets a password for future use).

## Social authentication

If you set up a Facebook or a Twitter App, and provide its configuration
details in your `general.yml`, then your users will be able to verify
reports/updates and log in using their social media account. Using this method,
FixMyStreet will still ask for and confirm an email address (if one is not
provided by Facebook). The login form on the site automatically adjusts
to allow people to pick whether to use the social login or the default email
authentication.

The Facebook App's domain should be set to your site's domain, and under
advanced settings the OAuth redirect URL should be yourdomain/auth/Facebook.

## Text authentication

If you set up a <a href="https://www.twilio.com/">Twilio</a> account and enter
the correct parameters in your configuration, you can also activate text
authentication, whereby instead of a confirmation email being sent, a
confirmation text is sent to the user's mobile containing a code they enter on
the site to continue with their report/update/logging in. The user flow
behaviour is otherwise identical, it is merely using a phone number instead of
an email for authentication.

On their profile page, users can add email/phone number, and verify ones they
may have entered previously but not verified.
