#!/usr/bin/perl -w -I../../perllib -I../../../perllib

# posters/index.cgi:
# List of publicity stuff on FixMyStreet
#
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: index.cgi,v 1.9 2008-10-14 10:28:38 matthew Exp $

use strict;
use Standard -db;
use mySociety::Config;
use mySociety::Web qw(ent);

# XXX: Ugh, as we're in a subdirectory
BEGIN {
    mySociety::Config::set_file("$FindBin::Bin/../../conf/general");
}

sub main {
    my $q = shift;
    print Page::header($q, title=>_('Publicity material'));
    print body($q);
    print Page::footer($q);
}
Page::do_fastcgi(\&main);

sub body {
    my $q = shift;
    my $badge = '<a href="http://www.fixmystreet.com/"> <img align="left" hspace="5" src="http://www.fixmystreet.com/i/fms-badge.jpeg" alt="FixMyStreet - report, view or discuss local problems" border="0"></a>';
    return $q->h1(_('Publicity Material')) .
        $q->div({style=>'float:left; width:50%'},
        '<p>Copy and paste the text below to add this badge to your site:</p>', $badge,
	'<textarea onclick="this.select()" cols=37 rows=5>' . ent($badge) . '</textarea>',
	'<p><small>(thanks to Lincolnshire Council for the image)</small></p>'
	) .
	$q->div({style=>'float:right; width:47%'},
        $q->p(_('Here are some posters and flyers you can use to publicise FixMyStreet:')) .
        '<img hspace="5" src="poster.png" alt="Example poster">' .
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
	)
    ;
}

