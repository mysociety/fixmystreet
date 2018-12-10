---
layout: page
title: Customising the design
author: dave
---

# Customising the design

<p class="lead">
  This page describes how to change the directionality and colour scheme of
  your installation &mdash; which is a good starting point for further
  customisations.
</p>

## Background

The CSS is stored in `web/cobrands/` under which there are directories for
Cobrands. Note that FixMyStreet uses SCSS and Compass to generate its CSS so
there are no CSS files until `bin/make_css` has been run as the site user.

The CSS provided with FixMyStreet uses CSS3 media queries in a mobile-first
format order to adapt the layout to work on different devices. It is structured
into these main files:

* `base.css` --
  all the styling for the content of the pages in a mobile sized browser.
* `layout.css` --
  all the styling for the content of the pages in a desktop sized browser.
* `_colours.css` --
  basic settings information, so you can easily make a site that
  looks different simply by copying these files to your own cobrand CSS
  directory, and changing the contents, as we will describe below.

Our `.gitignore` file assumes that any CSS files directly in a `cobrands/*`
directory are generated from SCSS - if you have CSS files that you want to use
directly, put them in a `css` directory within your cobrand directory.

# Tutorial

You can override any of the CSS or HTML templates of your FixMyStreet
installation, but to begin with it's a good idea to just change the colours.
That way you can learn how FixMyStreet customisation works, before tackling
more complex layout, design, or code changes.

## Start simple!

FixMyStreet's default CSS comes with a few basic colour settings which you can
change. Remember that ultimately **you can override any styling for your own
site** but most of this page shows how to set your own colours *without adding
any new HTML or CSS*. We know that you'll want to change more than just the
default colours: but this is the best way to start.

Once you've done this, you'll have your own <a href="{{ "/glossary/#cobrand" | relative_url }}"
class="glossary__link">cobrand</a>, and can start changing other stylesheets and
templates in the same way.


## Why you should create a cobrand

A cobrand is just FixMyStreet's way of separating your customisation from
everybody else's. To start with, this is almost as simple as putting what you
need in its own directory.

<div class="attention-box warning">
  You <em>can</em> simply edit the default settings (just edit the values in
  <code>web/cobrands/default/_colours.scss</code> and run
  <code>bin/make_css</code>) but we <strong>strongly recommend</strong> you do
  not do that. It's OK if you just want to play with the settings to see what's
  possible, but the right way to change how your site looks is to make a
  cobrand.
</div>

By making your own cobrand you'll be keeping your changes separate from the
core code, but also keeping it within the main repository. This has serious
benefits later on: it means you can easily update the FixMyStreet code (we
frequently add new features, for example) while retaining your changes.


## How to change the colours


This is the process:

1. pick a name for your cobrand
2. update your config to use the new cobrand
3. create a directory for it in `web/cobrands`
4. copy the default cobrand's CSS into it
5. edit the colours
6. run `bin/make_css`


The rest of this page describes each step in detail.


### Pick a name for your cobrand

Choose a name for your cobrand. In the examples below, we've used `fixmypark`,
but you can use anything provided it's not a cobrand already in use in the
code. Only use lower case letters. This name is never seen by the public &mdash;
it's FixMyStreet's internal name for it.

### Update your config to use the new cobrand

You need to tell FixMyStreet to use your cobrand instead of the default one.

FixMyStreet uses the 
<code><a href="{{ "/customising/config/#allowed_cobrands" | relative_url }}">ALLOWED_COBRANDS</a></code>
config variable to decide which cobrand to use. In `conf/general.yml`, set it to your new cobrand like this:

    ALLOWED_COBRANDS:
      - fixmypark

In fact, `ALLOWED_COBRANDS` is 
[a little more complex that it looks]({{ "/customising/config/#allowed_cobrands" | relative_url }}).
If you give it a list of cobrands, it will decide which one to use depending on string
matches on the incoming URL *for every request*  But for most cases you don't want it to switch.
So if you just specify just one cobrand like this, FixMyStreet will simply use it.

### Create a directory for your cobrand in web/cobrands

Make a new directory with your cobrand's name in `web/cobrands/` For example,
on the command line, do:
   
    cd fixmystreet
    mkdir web/cobrands/fixmypark


### Copy the default cobrand's CSS into yours

Copy the contents of `web/cobrands/default` into that directory.

    cp web/cobands/default/* web/cobrands/fixmypark
   
This puts the stylesheet files you need into your cobrand.
At this point, your cobrand is effectively a copy of the default one.

### Edit the colours

The default cobrand's colour scheme, which you have copied, will be blue and
orange &mdash; we picked startling colours to force people to want to customise it.

We use SCSS (instead of CSS) because it's a more powerful way of defining and
managing styles. This means that when you make any changes, FixMyStreet needs
to compile those SCSS files to rebuild the CSS &mdash; see the following
section.

You can edit the colours defined in `web/cobrands/fixmypark/_colours.scss`.
You'll need to use [web colour
codes](https://developer.mozilla.org/en-US/docs/Web/Guide/CSS/Getting_started/Co
lor) to specify the colours you want.

Be careful: if you're not familiar with SCSS, the syntax of that file is a
little strict. Typically, those colours *must* always be either exactly three
or six hex characters long. And there must be a `#` before and a semicolon after each one.

These are the colours which you can easily change within your copy of the
stylesheet:

<table class="table">
    <tr>
        <th>
            variable
        </th>
        <th>
            examples of where it's used in the default cobrand
        </th>
    </tr>
    <tr>
        <td>
            <code>$primary</code>
        </td>
        <td>
            the front page's main banner background
        </td>
    </tr>
    <tr>
        <td>
            <code>$primary_b</code>
        </td>
        <td>
            border around the the front page street/area input
        </td>
    </tr>
    <tr>
        <td>
            <code>$primary_text</code>
        </td>
        <td>
            text on the front page banner
        </td>
    </tr>
    <tr>
        <td>
            <code>$base_bg</code><br>
            <code>$base_fg</code>
        </td>
        <td>
            Large width page background/foreground (bleeding to edge)
        </td>
    </tr>
    <tr>
        <td>
            <code>$nav_background_colour</code><br>
            <code>$nav_colour</code>
        </td>
        <td>
            Mobile width, the header's colours; large width, the navigation's
            foreground colour
        </td>
    </tr>
    <tr>
        <td>
            <code>$menu-image</code>
        </td>
        <td>
            “Hamburger” menu colour (<code>menu-black</code> or
            <code>menu-white</code>)
        </td>
    </tr>
    <tr>
        <td>
            <code>$col_click_map</code><br>
        </td>
        <td>
            background of the "click map to report problem" banner on the
            map page
        </td>
    </tr>
    <tr>
        <td>
            <code>$col_fixed_label</code><br>
            <code>$col_fixed_label_light</code>
        </td>
        <td>
            border-top colour of the "fixed" label that appears above
            fixed reports, and its lighter background colour
        </td>
    </tr>
    <tr>
        <td>
            <code>$col_big_numbers</code>
        </td>
        <td>
            Colour to use for the step numbers on the front page.
        </td>
    </tr>
</table>

SCSS supports functions such as `darken` so you can specify colours that are
calculated from other colours like this:

    $col_click_map: #ee6040;
    $col_click_map_dark: darken($col_click_map, 10%);

For more about SCSS, see [the SASS website](http://sass-lang.com).


### Run make_css so FixMyStreet's CSS uses the new values

FixMyStreet now needs to absorb those changes by rebuilding the CSS. There's a
task in the `bin` directory called `make_css` that will do this for you. You'll
need to be logged into your shell in the `fixmystreet` directory as the site
user, then do:

    bin/make_css

This will update the CSS files. You can run the command just for your cobrand
by specifying the path to your cobrand’s SCSS as an argument, e.g.:

    bin/make_css web/cobrands/fixmypark

Keep an eye on the output of that command &mdash; if there's a problem (for
example, if you've made a mistake in the SCSS syntax, which is easy to do), it
will report it here.


### See the new colours

If you look at your site in a browser, you'll see the new colours. Remember
that every time you edit them, you need to run `bin/make_css` to make
FixMyStreet include the changes, or run `bin/make_css --watch` to have it
monitor for changes itself.


## Or... use your own CSS and HTML

Remember that *all* you've done here is change the colours, **using the
existing default CSS and HTML**. Of course any and all of this can be
overridden (by overriding CSS files and overriding the bits of HTML that you
want to change in the <a href="{{ "/glossary/#template" | relative_url }}"
class="glossary__link">templates</a>) but this is just so you can get going.

# Directionality

If you wish to use FixMyStreet in a right-to-left layout, this is very
straightforward and involves two steps:

* First, uncomment the line in your cobrand’s `_colours.scss` file as explained,
  so that the `$direction` variable is set to `right`.
* Secondly, create a copy of the `templates/web/base/header.html` in
  your own cobrand if you haven’t already (see
  [template customising]({{ "/customising/templates/" | relative_url }}) for more
  details) and uncomment the `SET` line that sets `dir="rtl"`.

That’s it; recompile your CSS, reload your site and you will find that
FixMyStreet has switched to a right-to-left layout. Your next step will
probably be to [change the language]({{ "/customising/language/" | relative_url }})
used by your site.

# Next steps...

If you want to customise the logo, [we have a tutorial for that](../logo/).

Now you have your own cobrand, adding your own HTML <a
href="{{ "/glossary/#template" | relative_url }}" class="glossary__link">templates</a> is straightforward.

Please see our separate page on [customising templates]({{ "/customising/templates/" | relative_url }}).

### Feeding back changes

Finally, when you've finished creating your cobrand you should consider
[feeding it back to us]({{ "/feeding-back" | relative_url }}) so it becomes part of the FixMyStreet repository.
