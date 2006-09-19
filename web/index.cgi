#!/usr/bin/perl -w -I../perllib -I../../perllib

# index.pl:
# Main code for BCI - not really.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: index.cgi,v 1.4 2006-09-19 16:34:24 matthew Exp $

use strict;
use CGI::Fast qw(-no_xhtml);
use Error qw(:try);
use Page;

my $q;

try {
    while ($q = new CGI::Fast()) {
        my $out = '';
        if ($q->param('pc')) {
            $out = display($q);
        } elsif ($q->param('map')) {
            $out = map_clicked($q);
        } else {
            $out = front_page();
        }

        print $q->header(-charset=>'utf-8');
        print Page::header($q, '');
        print $out;
        print Page::footer($q);

    }
} catch Error::Simple with {
    my $E = shift;
    my $msg = sprintf('%s:%d: %s', $E->file(), $E->line(), $E->text());
    warn "caught fatal exception: $msg";
    warn "aborting";
    encode_entities($msg);
    print "Status: 500\nContent-Type: text/html; charset=iso-8859-1\n\n",
            q(<p>Unfortunately, something went wrong. The text of the error
                    was:</p>),
            qq(<blockquote class="errortext">$msg</blockquote>),
            q(<p>Please try again later.);
};

sub front_page {
    return <<EOF;
<p>Welcome to Neighbourhood Fix-It.</p>

<form action="./" method="get">
<p>Enter your postcode: <input type="text" name="pc" value="">
<input type="submit" value="Go">
</form>
EOF
}

# This should use postcode, not x/y!
sub display {
    my $q = shift;
    my $x = $q->param('x') || 62;
    my $y = $q->param('y') || 171;
    my $dir = 'tl/';
    my $tl = $dir.$x.'.'.$y.'.png';
    my $tr = $dir.($x+1).'.'.$y.'.png';
    my $bl = $dir.$x.'.'.($y+1).'.png';
    my $br = $dir.($x+1).'.'.($y+1).'.png';
    my $out = Page::compass($x, $y);
    $out .= <<EOF;
        <div id="map">
            <div id="drag">
                <img id="2.2" nm="$tl" src="$tl" style="top:0px; left:0px;"><img id="3.2" nm="$tr" src="$tr" style="top:0px; left:250px;"><br><img id="2.3" nm="$bl" src="$bl" style="top:250px; left:0px;"><img id="3.3" nm="$br" src="$br" style="top:250px; left:250px;">
            </div>
        </div>
EOF
    return $out;
}
