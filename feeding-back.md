---
layout: page
title: Feeding back your changes
---

# Feeding back your changes

<p class="lead">We want people using the code to keep it as up to date as they can, so that
they gain the benefits of any changes made to the code by us or by other users.
To do this, we need your help when you are making changes to the code, feeding
the changes back to us and <a href="{{ "/updating/" | relative_url }}">updating your code</a>.</p>

**If you haven't done this, don't panic!**
Everything is solvable, and we fully understand that what little
time you have has been better spent getting the code to work at all for you
than to make sure it was done in the best possible way for the future. Get in
touch to discuss how best we can bring things together.

## 0. Setting up a fork of the repository to work on

Firstly, fork our repository on GitHub -- go to
[https://github.com/mysociety/fixmystreet](https://github.com/mysociety/fixmystreet)
and hit the Fork button.

If you've run the install script or used the AMI, the checkout there  will be
pointing at the mysociety repository. Let's add a new remote pointing at your
fork, replacing username with your GitHub username:

    git remote add fork https://github.com/<username>/fixmystreet
    git fetch fork
    git checkout -b our-master
    git push -u fork our-master

You can then make commits on the our-master branch. To then push your commits
to your fork, you would use:

    git push fork our-master

## 1. Make small, atomic changes

Git is easiest to work with if you make small, coherent commits, with good
commit messages. That way, it is easier to rearrange and adjust in order to get
things back upstream with pull requests and merges.

Even if you're working on your own on a fork, please do use git appropriately,
because that will only make it easier to integrate changes in the future. If
you simply edit files without any sort of version control, you will make things
very hard for yourself as well as for us.

## 2. Only make the minimal changes necessary

Please do not copy all the templates and all the stylesheets into your own
cobrand directories and then hack them until they work how you want. If you do
that, you will find it very hard to incorporate any changes and fixes to the
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

## 3. Changing the core code

If you need to make a change to some code that isn't in your cobrand's
templates, front end files, or cobrand `.pm` file, which may be necessary,
consider that other people may already be using the existing code. Can you add
a hook to a function in your cobrand file, so current users are unaffected? Do
feel free to [ask on the mailing list](/community/) about your proposed changes
and how best they could be implemented.

Please implement your changes in a fork of the repository on GitHub and submit
a pull request as soon as you can so that the changes can be discussed and
incorporated as soon as possible, reducing the amount of time your code and
upstream are apart.

