#!/usr/bin/perl -w -I../../perllib -I../../../perllib

# posters/index.cgi:
# List of publicity stuff on FixMyStreet
#
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: index.cgi,v 1.5 2007-08-29 23:03:17 matthew Exp $

use strict;
use Standard -db;
use mySociety::Config;

# XXX: Ugh, as we're in a subdirectory
BEGIN {
    mySociety::Config::set_file("$FindBin::Bin/../../conf/general");
}

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
	'<img align="right" hspace="5" src="poster.png" alt="Example poster">' .
        $q->p(_('Here are some posters you can use to publicise FixMyStreet.')) .
        $q->h2(_('Posters')) .
        $q->ul(
            $q->li($q->a({href=>'fixmystreet-poster-a4.pdf'}, _('A4, colour'))),
            $q->li($q->a({href=>'fixmystreet-poster-a4-bw.pdf'}, _('A4, black and white'))),
            $q->li($q->a({href=>'fixmystreet-poster-a4-bw-low-ink.pdf'}, _('A4, black and white, low ink'))),
            $q->li($q->a({href=>'fixmystreet-poster-a4-bw-outlined.pdf'}, _('A4, black and white, outlined'))),
        ) .
        $q->h2(_('Posters with tags')) . 
        $q->ul(
            $q->li($q->a({href=>'fixmystreet-poster-tags.pdf'}, _('A4, colour'))) .
            $q->li($q->a({href=>'fixmystreet-poster-tags-bw.pdf'}, _('A4, black and white'))) .
            $q->li($q->a({href=>'fixmystreet-poster-tags-bw-low-ink.pdf'}, _('A4, black and white, low ink'))) .
            $q->li($q->a({href=>'fixmystreet-poster-tags-only.pdf'}, _('A4, tags only')))
        ) .
        $q->h2(_('Flyers')) .
        $q->ul(
            $q->li($q->a({href=>'fixmystreet-flyers-colour.pdf'}, _('4 x A6, colour'))),
            $q->li($q->a({href=>'fixmystreet-flyers-bw-outlined.pdf'}, _('4 x A6, black and white, outlined'))),
            $q->li($q->a({href=>'fixmystreet-flyers-bw-low-ink.pdf'}, _('4 x A6, black and white, low ink')))
        )
    ;
}

