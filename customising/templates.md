---
layout: page
title: Customising templates
---

# Customising FixMyStreet templates

<p class="lead">This document explains how template inheritance works
and how to create your own custom templates.</p>

When it's building a page, FixMyStreet always looks in your cobrand's web
template directory first: if it finds a template there, it uses it, and if it
doesn't it falls back and uses the `fixmystreet` or `base` one instead.
To see how this works, look at some of the cobrands that already exist in the
`templates/web` directory. You need to create a new directory with your
cobrand's name: for example, do:

    mkdir templates/web/fixmypark

Then, to override an existing template, copy it into the
`templates/web/fixmypark/` directory and edit it there. You *must* use the
same directory and file names as in the parent cobrand (that is, in
`templates/web/fixmystreet` or `templates/web/base` - base might be default if
you have an older version of the code).

<div class="attention-box">
    <strong>Please note:</strong> only make template files for those things you
    need to do differently; you do not need to copy all the files into your own
    templates folder. If the change you want to make is very small to the
    base template, you could consider just adding an <code>IF</code>
    statement to that parent template instead. The
    <a href="/feeding-back/">Feeding back page</a> has more details.
</div>

For example, it's likely you'll want to change the footer template, which puts
text right at the bottom of every page. Copy the footer template into your
cobrand like this:

    cp templates/web/fixmystreet/footer.html templates/web/fixmypark/

The templates use the popular <a
href="http://www.template-toolkit.org">Template Toolkit</a> system &mdash; look
inside and you'll see HTML with placeholders like `[% THIS %]`. The `[% INCLUDE
...%]` marker pulls in another template, which, just like the footer, you can
copy into your own cobrand from `fixmystreet` or `base` and edit.

<div class="attention-box warning">
    One thing to be careful of: <strong>only edit the <code>.html</code> files</strong>. FixMyStreet
    generates <code>.ttc</code> versions, which are cached copies &mdash; don't edit these, they
    automatically get created (and overwritten) when FixMyStreet is running.
</div>

The other template you will probably make your own version of is the FAQ which
is in `templates/web/fixmystreet/faq/faq-en-gb.html`. If you translate it too,
you will need to rename it accordingly.

## Emails

There are also email templates that FixMyStreet uses when it constructs email
messages to send out. You can override these in a similar way: look in the
`templates/email` directory and you'll see cobrands overriding the templates in
`templates/email/default`.
