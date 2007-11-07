#!/usr/bin/perl -w -I../perllib

# fun.cgi:
# Weird and Wonderful
#
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: fun.cgi,v 1.1 2007-11-07 15:24:07 matthew Exp $

use strict;
use Standard -db;

# Main code for index.cgi
sub main {
    my $q = shift;
    print Page::header($q, title=>_('Weird and Wonderful reports'));
    print fun($q);
    print Page::footer();
}
Page::do_fastcgi(\&main);

sub fun {
    my $q = shift;
    my $out = $q->h1(_('Weird and Wonderful reports'));
    $out .= $q->p('Here are some of the best or strangest reports we&rsquo;ve seen on FixMyStreet.
They&rsquo;ve all been fixed, and in one case could have saved lives!
Do let us know if you find any more.');
    $out .= $q->ul({style => 'list-style-type: none; margin:0; padding:0'},
        $q->li(
	    $q->img({src=>'http://www.fixmystreet.com/photo?id=9468', align=>'right', hspace=>8}),
	    $q->h2('Dumped Piano (right)'),
	    $q->p('The reporter of this problem summed it up with their report,
which consisted solely of the one character &ldquo;!&rdquo;. &mdash;',
$q->a({href=>'http://www.fixmystreet.com/?id=9468'}, 'Problem report')),
	),
        $q->li(
	    $q->h2('Mad Seagull'),
	    $q->p('&ldquo;A seagull is attacking various cars within this road. He starts at around 05:45 every morning and continues until around 19:30. This causes a lot of noisy banging and wakes up children.&rdquo; &mdash;',
$q->a({href=>'http://www.fixmystreet.com/?id=2722'}, 'Problem report')),
	),
        $q->li(
	    $q->img({src=>'http://www.fixmystreet.com/photo?id=6553', align=>'right', hspace=>8}),
	    $q->h2('Boxes full of cheese dumped (right)'),
	    $q->p('&ldquo;About a dozen boxes full of mozzarella cheese have been dumped opposite 3 rufford street. if it warms up we could have nasty road topping problem (seriously there is a lot of cheese)&rdquo; &mdash;',
$q->a({href=>'http://www.fixmystreet.com/?id=6553'}, 'Problem report')),
	),
        $q->li(
	    $q->h2('Dangerous Nivea Billboard'),
	    $q->p('&ldquo;The Nivea \'Oxygen is a wonderful thing\' billboard here has a device on it releasing bubbles and foam. This is blowing into the road which is both distracting and dangerous to drivers. A large ball of foam hit my windscreen unexpectedly and nearly caused me to have an accident&rdquo; &mdash;',
$q->a({href=>'http://www.fixmystreet.com/?id=7552'}, 'Problem report')),
	),
    );
    return $out;
}

