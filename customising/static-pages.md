---
layout: page
title: Adding static pages
---

# Adding static pages

<p class="lead">How to add your own static pages to your installation.</p>

If you wish to add a new static page to your site, then you can place a
template file, say `team.html`, in the `templates/web/cobrand/about/`
directory, where `cobrand` should be replaced with your cobrand name (as
explained in [customising FixMyStreet templates](../templates/)).

The page will then be available to view at `/about/team` on your site.

Have a look at the existing files in `templates/web/base/about/` for an idea
of the contents of a file – you need a header and a footer include, but other
than that the contents are up to you.

If you want the page to be available in multiple languages, then name your file
`team-LANG.html` for each language and it will automatically be used. For
example, if your site is available in Welsh and French, you could have
`team-cy.html` and `team-fr.html`

<hr>

As a special case, if you create an `about/homepage.html` template file, then
it will be used as the front page of your site, and the normal front page will
instead be available at `/report`.

<hr>

If you wish to do more complex pages, or wish to then we recommend setting up
e.g. a WordPress installation running at a subdomain of your site.
