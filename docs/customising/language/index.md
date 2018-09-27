---
layout: page
title: Changing the language
---

# Changing the language

<p class="lead">Here we explain how to change what language is displayed on 
FixMyStreet, how to contribute your own if we don&rsquo;t have yours, and how to
run a site in multiple languages.</p>

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

Using the example above `http://fr.fixmystreet.com/` would display the
French translation and `http://de.fixmystreet.com/` would display the
German translation. If no language is specified in the URL, or an
unsupported code is used then it will fall back to the language
negotiated by the browser. If that language is not available,
the first language listed in the `LANGUAGES` configuration option
will be displayed.

Note that this method only supports two letter language codes. This
means you cannot use `sv-se` format strings to distingish regional
variants in the hostname. However, the first part of the language string
does not need to be an official language code so you can use it to allow
regional variants, e.g:

    LANGUAGES:
        - 'sv,Svenska,sv_SE'
        - 'sf,Svenska,sv_FI'

`http://sv.fixmystreet.com` would display `sv_SE` and
`http://sf.fixmystreet.com` would display `sv_FI`. However, this would
not be detected automatically (at the bare domain) if the user's browser was
set to sv-fi.

These language links can be used for adding a language switcher to the
site. For example, a basic two language switcher:

    [% IF lang_code == 'fr' %]
        <li><a href="https://en.[% c.cobrand.base_host %][% c.req.uri.path_query %]">English</a></li>
    [% ELSE %]
        <li><a href="https://fr.[% c.cobrand.base_host %][% c.req.uri.path_query %]">Français</a></li>
    [% END %]

## Ensuring links in emails default to the right language

With the default configuration links in emails will use the `BASE_URL`
and hence clicking on them means the user will see the browser
negotiated language. This behaviour can be changed using the
`base_url_with_lang` function in your Cobrand module which is used
when generating URLs for emails.

A basic version of this that supports two languages would look like
like this:

    sub base_url_with_lang {
        my $self = shift;
        my $base = $self->base_url;
        my $lang = $mySociety::Locale::lang;
        if ($lang eq 'fr') {
            $base =~ s{https?://}{$&fr.};
        } else {
            $base =~ s{https?://}{$&en.};
        }
        return $base;
    }

The current language is stored when a report is made and this is used
when sending out emails related to the report. When the email is sent
this means that `$mySociety::Locale::lang` returns the language used at
the time the report was submitted, hence the function above will return
URLs for the correct language.

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

## Translating the FAQ and other static pages

Static pages do not use gettext so need to be translated separately by
creating a new template under your cobrand, e.g. for a German
translation of the FAQ:

  templates/web/<cobrand>/about/faq-de.html

For other languages the file should be `faq-<lang>.html`. If there is
not a translated template it will fall back to `faq.html`.

## Translating body names, categories, and report states

As long as you have set up the <code>LANGUAGES</code> configuration first, you
will find that in the admin you can give translations for each of body names,
report categories, and report states. These translations will be used as
appropriate depending upon the language of the front end.
