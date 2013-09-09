# Trouble shooting

## Empty datetime object

    Couldn't render template "index.html: undef error - Can't call method "strftime" without a package or object reference at /var/www/fixmystreet.127.0.0.1.xip.io/fixmystreet/perllib/Utils.pm line 232

- You might have a problem with a datefield that has been left empty by one cobrand that another expects to have a value. Inspert the problem table in the database.
- You may have problems being returned by memcached that your database does not have. Restart memcached to rule this out.

## Wrong cobrand is displaying

- Make sure that your hostname does not contain anything that another cobrand is matching on. For example if your config is

``` yaml
ALLOWED_COBRANDS:
  - fixmystreet
  - zurich
````

Then a domain like `zurich.fixmystreet.com` will match `fixmystreet` first and that is the cobrand that will be served.

## Account creation emails not arriving

Your receiving email servers may be rejecting them because:

* your VM IP address has been blacklisted
* your ISP blocks outgoing connections to port 25 (mobile broadband providers often do this)
* sender verification has failed (applies to `@mysociety.org` servers) - check that your `DO_NOT_REPLY_EMAIL` conf setting passes sender verification (using your own email address works well).

Perhaps check the entries in `/var/log/mail.log` to check that the message has been sent by the app, and if it has been possible to send them on.

## Translations not being used

The locale needs to be installed too or the translations will not be used. Use
`locale -a` to list them all and ensure the one your translation uses is in the
list.


## Database connection errors trying to run update-schema

Make sure that you specify a database host and password in `general.yml`. You
may need to explicitly give your user a password.
