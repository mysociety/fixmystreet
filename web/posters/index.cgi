#!/usr/bin/perl -w

# posters/index.cgi:
# List of publicity stuff on FixMyStreet
#
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: index.cgi,v 1.1 2007-06-28 14:17:33 matthew Exp $

use strict;
require 5.8.0;

# Horrible boilerplate to set up appropriate library paths.
use FindBin;
use lib "$FindBin::Bin/../../perllib";
use lib "$FindBin::Bin/../../../perllib";
use Page;

# Main code for index.cgi
sub main {
    my $q = shift;
    print Page::header($q, title=>_('Publicity material'));
    print body($q);
    print Page::footer();
}
Page::do_fastcgi(\&main);

sub body {
    my $q = shift;
    return $q->h1(_('Publicity Material')) .
        $q->p(_('Here are some posters you can use to publicise FixMyStreet.')) .
        $q->h2(_('Posters')) .
	'<img align="right" hspace="5" src="poster.png" alt="Example poster">' .
        $q->ul(
            $q->li($q->a({href=>'fixmystreet-poster-a4.pdf'}, _('A4, colour'))),
            $q->li($q->a({href=>'fixmystreet-poster-a4-bw.pdf'}, _('A4, black and white'))),
            $q->li($q->a({href=>'fixmystreet-poster-a4-bw-low-ink.pdf'}, _('A4, black and white, low ink'))),
            $q->li($q->a({href=>'fixmystreet-poster-a4-bw-outlined.pdf'}, _('A4, black and white, outlined'))),
        ) .
        $q->h2(_('Posters with tags')) . 
	'<img align="right" hspace="5" src="tags.png" alt="Example poster with tags">' .
        $q->ul(
            $q->li($q->a({href=>'fixmystreet-poster-tags.pdf'}, _('A4, colour'))) .
            $q->li($q->a({href=>'fixmystreet-poster-tags-bw.pdf'}, _('A4, black and white'))) .
            $q->li($q->a({href=>'fixmystreet-poster-tags-bw.pdf'}, _('A4, black and white, low ink'))) .
            $q->li($q->a({href=>'fixmystreet-poster-tags-only.pdf'}, _('A4, tags only')))
        ) .
        $q->h2(_('Flyers')) .
        $q->ul(
            $q->li($q->a({href=>'fixmystreet-flyers-colour.pdf'}, _('4 x A5, colour'))),
            $q->li($q->a({href=>'fixmystreet-flyers-bw-outlined.pdf'}, _('4 x A5, black and white, outlined'))),
            $q->li($q->a({href=>'fixmystreet-flyers-bw-low-ink.pdf'}, _('4 x A5, black and white, low ink')))
        )
    ;
}

