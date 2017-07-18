---
layout: page
title: Changing the language
---

# Changing the language

<p class="lead">Here we explain how to change what language is displayed on 
FixMyStreet, how to contribute your own if we don&rsquo;t have yours, and how to
run a site in multiple languages. <strong>Work in progress.</strong></p>

## Setup

The translations for most FixMyStreet strings are stored as standard 
<a href="{{ "/glossary/#gettext" | relative_url }}" class="glossary__link">gettext</a>
files, in `FixMyStreet.po` files under `locale/<lang>/LC_MESSAGES/`. A
few full pages, such as the FAQ, and emails, are stored separately in the
templates directory and should be translated by creating new templates in your
cobrand.


Firstly, set the
<code><a href="{{ "/customising/config/#languages" | relative_url }}">LANGUAGES</a></code>
configuration option to the languages your site uses. This is an array of
strings specifying what language or languages your installation uses. For
example, if your site is available in English, French, and German, you would
have:

    LANGUAGES:
        - 'en-gb,English,en_GB'
        - 'fr,French,fr_FR'
        - 'de,German,de_DE'

This would then set up things appropriately to use the relevant language files
you have made.

You must make sure that the locale for any language you use is installed on the
server in order for the translations to work properly. On Debian, you can alter
`/etc/locale.gen` and run `sudo locale-gen`. On Ubuntu, you can just run `sudo
locale-gen <LOCALE_NAME>`.

## Seeing the site in your language

By default, FixMyStreet is set up so visiting a hostname starting with the
two-letter language code will use that language; otherwise it will detect based
upon the browser. If you have used the install script on a clean server, or the
AMI, you should be able to visit your domain with a language code at the start
by default.

## Contributing a translation

If we don't already have a translation for the language you want, please do
consider contributing one :) You can use our repository on
[Transifex](https://www.transifex.com/projects/p/fixmystreet/),
or translate the `.po` files directly using a local program such as
[PoEdit](http://www.poedit.net/).

The templates use the `loc` function to pass strings to gettext for
translation. If you create or update a `.po` file, you will need to run the
`commonlib/bin/gettext-makemo` script to compile these files into the machine
readable format used by the site.
