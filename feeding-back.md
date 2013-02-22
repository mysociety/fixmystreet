---
layout: default
title: Feeding back your changes
---

# Feeding back your changes

We want people using the code to keep it as up to date as they can, so that
they gain the benefits of any changes made to the code by us or by other users.
To do this, we need your help when you are making changes to the code, feeding
them back to us and [updating your code](/updating/).

## Only make the minimal changes necessary

Firstly, please do not copy all the templates and all the stylesheets into your
own cobrand directories and then hack them until they work how you want. If you
do that, you will find it very hard to incorporate any changes and fixes to the
parent templates/CSS that are made, as your own forked copies will override
them.

Instead, copy only the templates, or bits of templates, you need, and inherit
the existing CSS and change only what you need to change. If you only want to
change one bit of a template, consider the following options:

1. If it's a tiny one line change, perhaps simply add an `IF` statement to the
template using `c.cobrand.moniker`. There are many such examples in the
existing templates.
2. If it's slightly larger, think about creating a new template containing the
relevant bit of this template, which you can then override in your cobrand
template directory. Again, there are many existing examples.
3. Only now consider copying a whole template, if you need to make substantial
changes to the parent. And be aware of having to notice changes to the parent
that might affect your copy.

If you need to change the CSS, override it in your cobrand's `base.scss` or
`layout.scss` -- consider if the CSS could be changed, e.g. a variable added,
in order to reduce the amount of overriding needed. But in general the amount
needed is not large.

## Changing the core code

If you need to make a change to some code that isn't in your cobrand's
templates, front end files, or cobrand `.pm` file, which may well be necessary,
consider that other people may already be using the existing code. Can you add
a hook to a function in your cobrand file, so current users are unaffected? Do
feel free to ask on the mailing list about your proposed changes and how best
they could be implemented.

Please implement your changes in a fork of the repository on github and submit
a pull request as soon as you can so that the changes can be discussed and
incorporated as soon as possible, reducing the amount of time your code and
upstream are apart.

## What to do if you haven't done this

*Don't panic!* Everything is solvable, and we fully understand that what little
time you have has been better spent getting the code to work at all for you
than to make sure it was done in the best possible way for the future. Get in
touch to discuss how best we can bring things together.

<!--
However, there are things you can do if you have time that can help.
Say you have a repository where you forked from FixMyStreet some time ago, and
have made numerous commits on top of it, such that you think merging with
upstream master (see our [page on updating](/updating/)) will cause many
conflicts and anguish. As one example, you've manually altered some text in a
JavaScript file in to your language, whilst upstream has moved that text into
the .po file for easier translation.
-->

