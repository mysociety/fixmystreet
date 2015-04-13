---
layout: page
title: Adding new strings to FixMyStreet
---

# Adding new strings

<p class="lead">Technical details for people who wish to add new strings for
translation.</p>

You will need to install the Locale::Maketext::Extract package in order to
parse strings out of templates:

    $ cpanm -l local-carton Locale::Maketext::Extract

A new clean `.po` file, containing all the strings marked for translation in
the code and templates, can be created by running the `bin/gettext-extract`
script.

    export PERL5LIB="local-carton/lib/perl5:local/lib/perl5"
    export PATH="local-carton/bin:$PATH"
    bin/gettext-extract

To merge in new strings with the existing translations:

    bin/gettext-merge

To compile translations into `.mo` files:

    commonlib/bin/gettext-makemo

You may find it helpful to add an alias to your .gitconfig:

    [alias]
        podiff = "!f() { git diff --color $@ | grep -v '^ ' | grep -v @@ | grep -v '#:' | less -FRSX; }; f"

Then `git podiff locale` will show you actual changes, rather than all the
changes to comments and line numbers.
