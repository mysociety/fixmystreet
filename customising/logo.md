---
layout: page
title: Customising the logo
author: matthew
---

# Customising the logo

<p class="lead">
  This page describes how to change the logo of your installation.
</p>

## Background

Do make sure you have followed the
[initial CSS guide]({{ "/customising/css/" | relative_url }}) first to set up the
initial CSS for your own cobrand. There are a few ways you can have your own
logo on your cobrand, which we will go through below. We first talk about
replacing the image itself, and then changing the size.

## Edit the sprite image

If you have image editing capabilities, you can make a copy of the
`web/cobrands/fixmystreet/images/sprite.png` file in your cobrand directory,
edit it, and then set the `$image-sprite` variable in your `_colours.sass`
file, e.g.:

    $image-sprite: '/cobrands/fixyourpark/images/sprite.png';

As normal, run `bin/make_css` to recompile your CSS. The normal logo is 175x40
pixels, the front page logo is 300x60.

## Using a separate image

If you wish to use a different logo in its own file, you will need two logos of
different sizes (by default 175x40 and 300x60 for the front page); in your
`base.scss` you should set the `background` property of `#site-logo` to your
small logo, and in `layout.scss` you should set the `background` property of
`body.frontpage #site-logo`.

## Using a differently sized logo

If, on top of the either of the above options, you wish to use a different
sized logo, then you will need to also set the `width` and `height` properties
of the two `#site-logo` entries. If you are increasing the height, you may also
need to increase the height of `#site-header` in `base.scss` (for the front
page logo, `body.frontpage #site-header` in `layout.scss`).
