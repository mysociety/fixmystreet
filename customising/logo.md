---
layout: page
title: Customising the logo
author: matthew
---

# Customising the logo

<p class="lead">
  This page describes how to change the logo of your installation.
</p>

Do make sure you have followed the
[initial CSS guide]({{ "/customising/css/" | relative_url }}) first to set up the
initial CSS for your own cobrand.

To use a different logo, by default you should have an image 175x35 in size,
preferably placed in `web/cobrands/YOURCOBRAND/` somewhere. You should then set
the `background-image` property of `#site-logo` in your `base.scss`. If you
wish a differently sized logo, you will also need to set the `width`, `height`,
and `background-size` properties of `#site-logo`. Note if you make it larger in
height, you might also need to investigate e.g. `$mappage-header-height`.

On fixmystreet.com we use a larger logo on the desktop front page; if you wish
to do the same, in your `layout.scss` set the `background-image` of
`body.frontpage #site-logo`, along with (as before) corresponding `width`,
`height`, and `background-size`. See fixmystreet.com’s `layout.scss` for how it
does it, though note it is a bit more complex as it uses SVG with a PNG
fallback.
