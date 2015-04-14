---
layout: page
title: Changing the language
---

# Changing the language

<p class="lead">Here we explain how to change what language is displayed on 
FixMyStreet, how to contribute your own if we don&rsquo;t have yours, and how to
run a site in multiple languages.</p>

## Is FixMyStreet already available in your language?

You need to know your language code (for example: `fr_FR` for French, or
`fr_CA` for Canadian French). See this
[W3.org article](http://www.w3.org/International/articles/language-tags/)
if you're not sure what code to use.

<div class="attention-box info">
  Look in FixMyStreet's <code>locale/</code> directory.
  If there is already a translation available for your language, you'll see
  a directory whose name matches your language code in <code>locale/</code>.
</div>
<div class="attention-box helpful-hint">
    For example, there <em>is</em> a <code>locale/sv_SE.UTF-8</code> directory,
    because a Swedish (<code>sv_SE</code>) translation of FixMyStreet is
    available.
</div>

It's possible that FixMyStreet's translation for your language is incomplete.
If this is the case, some of the text (the strings that have not been
translated) may appear in English. See more about
[incomplete translations](#incomplete-translations) below.

Even if there is no directory for your language in `locale/`, there *might* be
a partial translation for it that hasn't been brought into the source code yet.
Check on Transifex in case work on a translation in your language has been
started.


## Setup

<div class="attention-box helpful-hint">
  To support a specific language you must ensure:
  <ul>
    <li>a translation is available</li>
    <li>the language is explicitly included in the <code>LANGUAGES</code> setting</li>
    <li>the <em>locale</em> is supported by your server</li>
    <li>(for multiple languages) you've considered how a user chooses which one to use</li>
  </ul>
</div>

There are two places where translations are stored:

* The translations for most FixMyStreet strings are stored as standard 
  <a href="{{ site.baseurl }}glossary/#gettext" class="glossary__link">gettext</a>
  files, in `FixMyStreet.po` files under `locale/<lang>/LC_MESSAGES/`.

* A few full pages, such as the FAQ, and the templates for emails are stored
  separately in the `templates/` directory. Translations of these pages are made
  by creating new templates in your
  <a href="{{ site.baseurl }}glossary/#cobrand" class="glossary__link">cobrand</a>.

You must set the [`LANGUAGES`]({{ site.baseurl }}customising/config/#languages)
configuration option to the language (or languages) you want your site to use.
This is an array of strings specifying what language or languages your
installation will support. For example, if your site is available in English,
French, and German, you would have:

    LANGUAGES:
        - 'en-gb,English,en_GB'
        - 'fr,French,fr_FR'
        - 'de,German,de_DE'

The first and last item in the string map the language code (`fr`) to the
appropriate translation file (`fr_FR_`). The middle item is the name of the
language that can be used in a language-switching interface (in practice,
FixMyStreet generally doesn't use this).

You must make sure that the locale for any language you use is installed on the
server in order for the translations to work properly: 

   * On Debian, you can alter
     `/etc/locale.gen` and run `sudo locale-gen`.
   * On Ubuntu, you can just run `sudo locale-gen <LOCALE_NAME>`.

## Seeing the site in your language

By default, FixMyStreet is set up so visiting a hostname starting with the
two-letter language code will use that language. If no language is specified
in this way, it will detect based on the browser (browsers typically send
information in the headers of each request indicating what language the user
prefers).

If you have used the 
[install script]({{ site.baseurl }}install/install-script/) on a clean server,
or the [AMI]({ site.baseurl }}install/ami/), you should be able to visit your
domain with a language code at the start (for example,
<code>fr.example.com</code>).

<div class="attention-box warning">
  Remember you must also specify this language in the
  <code><a href="{{ site.baseurl }}customising/config/#languages">LANGUAGES</a></code>
  configuration setting. FixMyStreet will only support languages you have
  explicitly enabled in this way.
</div>

If you want to provide an explicit way for your users to switch between languages,
you can add it to the header template &mdash; for example, a button or drop-down
to explicitly use the subdomain in the URL for the chosen language. Obviously,
you need to configure your site to support each of the languages in this way
for this to work.


## Contributing a translation

If we don't already have a translation for the language you want, please do
consider contributing one :) You can use our repository on
[Transifex](https://www.transifex.com/projects/p/fixmystreet/),
or translate the
<a href="{{ site.baseurl }}glossary/#po" class="glossary__link">.po&nbsp;files</a>
directly using a local program such as
[PoEdit](http://www.poedit.net/).

The templates use the `loc` function to pass strings to gettext for
translation. If you create or update a `.po` file, you will need to run the
`commonlib/bin/gettext-makemo` script to compile these files into the machine
readable format used by the site. There's more detail about this process in
the page about [adding new strings]({{ site.baseurl }}customising/language/technical/).

If you're not sure how to manage a translation,
[contact us]({{site.baseurl}}community) and ask for help.


## Incomplete translations

It's possible that the translation files for your language already exist, but
are not complete. If you can see your language on Transifex, it's very likely
that the "percentage complete" is *not* 100% &mdash; this is normal. It means
that not all the strings in the
<a href="{{ site.baseurl }}glossary/#po" class="glossary__link">.po&nbsp;file</a>
have been translated. There are several reasons for this:

* The cobrand that was using this translation did not need all of it &mdash;
  it's OK to only translate the parts of the site that are shown to the user,
  so (for example) any strings that are shown in the admin might not need to be
  translated.

* The translation may be a little out of date &mdash; FixMyStreet is under
  active development and new strings are added all the time, so a even complete
  translation will quickly become less than 100% covered.

* The translation may have been done for a project that never got to launch, so
  was not finished.
  
In all these cases you can build on the work that has already been done by
contributing to the existing translation.
[Contact us]({{site.baseurl}}community) to find out what the current state of
the translation you're interested in is, because we probably know the history
of the work that's already been done on it. We may be able to put you in touch
with people who are already working on it.

<div class="attention-box helpful-hint">
   Even if there's a complete translation available for your language, you'll
   almost certainly need to change some of the templates (such as the FAQ
   page, and the templates for emails that are sent out), because these are
   specific to your own project. If there's already a translation available,
   you can copy those files into your own
   <a href="{{site.baseurl}}glossary/#cobrand" class="glossary__link">cobrand</a>
   and then edit them.
</div>

## Adding new strings: technical details

If you're a developer and you add new strings to FixMyStreet, you need to 
make those strings available for translators.
See [Adding new strings]({{site.baseurl}}customising/language/technical/)
for the technical details of this process.
