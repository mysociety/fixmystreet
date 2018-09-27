---
layout: page
title: Customising
---

# Customising FixMyStreet

<p class="lead">
  When you set up your FixMyStreet site, you'll want to tailor the
  default installation to your own requirements. This includes limiting
  the geographic area it will accept problem reports for, the language
  it's presented in, and how it looks.
</p>


## Your own cobrand

Whatever you change, you'll almost certainly need to create a
<a href="{{ "/glossary/#cobrand" | relative_url }}" class="glossary__link">cobrand</a>,
which is the mechanism FixMyStreet uses to let you deviate from its default
appearance and behaviour.

As well as the
[configuration settings]({{ "/customising/config/" | relative_url }}) you specify in
the `conf/general.yml` file, a cobrand is made up of a set of templates, CSS,
and an *optional* Cobrand module that contains custom Perl code. There are
defaults for all of these, so the cobrand only needs to override things that are
specific to it.

We *strongly recommend* you follow this system -- rather than just editing
existing files -- because it means that you'll be able to upgrade FixMyStreet
without the updates overwriting your unique changes.

It's a good idea for a cobrand to have the same name as your site. For example,
if your site is `www.FixMyPark.com` then your cobrand could be called FixMyPark
(with the "moniker" all lowercase, like this: `fixmypark`, which is used for
things like directory names). The default cobrand is called Default (`default`).


## What you can change

There's a lot you can customise on your own FixMyStreet site.

We've prepared a [customisation checklist]({{ "/customising/checklist/" | relative_url }})
which covers all the key things you should work through when installing your own 
site.

But if you just want to see what's possible, here are some of the
aspects of FixMyStreet that you can customise:

* [how to translate or change FixMyStreet's language]({{ "/customising/language/" | relative_url }})
* [how FixMyStreet assigns reports to bodies]({{ "/customising/fms_and_mapit/" | relative_url }})
* [how to customise the geocoder]({{ "/customising/geocoder/" | relative_url }})
* [how to change the design]({{ "/customising/css/" | relative_url }})
* [how to customise templates]({{ "/customising/templates/" | relative_url }})
* [how reports are sent by FixMyStreet]({{ "/customising/send_reports/" | relative_url }})
* [all the config settings]({{ "/customising/config/" | relative_url }})

Note that none of the above require you to know or write any Perl (the language 
FixMyStreet is mostly written in). 

### The Cobrand module

If you need more customistation than the config settings and templates give you,
you'll probably need to make a Cobrand module. This is a Perl module that is automatically
loaded according to the current cobrand -- you can see existing examples in
[`perllib/FixMyStreet/Cobrand/`](https://github.com/mysociety/fixmystreet/tree/master/perllib/FixMyStreet/Cobrand).
There is a default Cobrand 
([`Default.pm`](https://github.com/mysociety/fixmystreet/blob/master/perllib/FixMyStreet/Cobrand/Default.pm))
that all Cobrands should inherit from. A Cobrand module can then override any
of the methods from the default Cobrand.
See [more about Cobrand modules](/customising/cobrand-module/).

## Feeding back changes

It would be great if the changes you make to the code could be fed back
upstream to benefit other users. Obviously if you've only customised templates
and CSS you may not feel you have to, but it's likely you'll have needed to
make actual code changes for your particular environment, and feeding these
back means it is easier to update the code from upstream in future to gain new
features and bugfixes.
See [more about feeding back changes]({{ "/feeding-back/" | relative_url }}).
