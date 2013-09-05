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
