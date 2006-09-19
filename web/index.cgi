#!/usr/bin/perl -w

# index.pl:
# Main code for BCI - not really.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: index.cgi,v 1.6 2006-09-19 23:32:55 matthew Exp $

use strict;
require 5.8.0;

# Horrible boilerplate to set up appropriate library paths.
use FindBin;
use lib "$FindBin::Bin/../perllib";
use lib "$FindBin::Bin/../../perllib";

use Page;
use mySociety::Config;
BEGIN {
    mySociety::Config::set_file("$FindBin::Bin/../conf/general");
}
use mySociety::MaPit;
mySociety::MaPit::configure();

# Main code for index.cgi
sub main {
    my $q = shift;

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
Page::do_fastcgi(\&main);

# Display front page
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
    my $pc = $q->param('pc');

    my $areas = mySociety::MaPit::get_voting_areas($pc);
    # XXX Check for error
    return 'Uncovered area' if (!$areas || !$areas->{LBO});

    my $lbo = $areas->{LBO};
    return 'Not covered London borough' unless ($lbo == 2510 || $lbo == 2492);
    my $area_info = mySociety::MaPit::get_voting_area_info($lbo);
    my $name = $area_info->{name};

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
