#!/usr/bin/perl -w

# index.pl:
# Main code for BCI - not really.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: index.cgi,v 1.8 2006-09-20 12:47:27 francis Exp $

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
    my $error = shift;
    my $out = '';
    $out .= '<p id="error">' . $error . '</p>' if ($error);
    $out .= <<EOF;
<p>Report a problem with refuse, recycling, fly tipping, pest control,
abandoned vechicles, street lighting, graffiti, street cleaning, litter or
similar to your local council.</p>

<p><strong>This is currently only for Newham and Lewisham Councils</strong></p>

<p>It&rsquo;s very simple:</p>

<ol>
<li>Enter postcode
<li>Find problem on map
<li>Enter details of problem
<li>Send!
</ol>

<form action="./" method="get">
<p>Enter your postcode: <input type="text" name="pc" value="">
<input type="submit" value="Go">
</form>
EOF
    return $out;
}

# This should use postcode, not x/y!
sub display {
    my $q = shift;
    my $pc = $q->param('pc');

    my $areas = mySociety::MaPit::get_voting_areas($pc);
    # XXX Check for error

    # Check for London Borough
    return front_page('I\'m afraid that postcode isn\'t in our covered area') if (!$areas || !$areas->{LBO});

    # Check for Lewisham or Newham
    my $lbo = $areas->{LBO};
    return front_page('I\'m afraid that postcode isn\'t in our covered London boroughs') unless ($lbo == 2510 || $lbo == 2492);

    my $area_info = mySociety::MaPit::get_voting_area_info($lbo);
    my $name = $area_info->{name};

    my $out = '<h2>' . $name . '</h2>';

    my $x = $q->param('x') || 620;
    my $y = $q->param('y') || 1710;
    my $dir = mySociety::Config::get('TILES_URL');
    my $tl = $x.'.'.$y.'.png';
    my $tr = ($x+1).'.'.$y.'.png';
    my $bl = $x.'.'.($y+1).'.png';
    my $br = ($x+1).'.'.($y+1).'.png';
    my $tl_src = $dir.$tl;
    my $tr_src = $dir.$tr;
    my $bl_src = $dir.$bl;
    my $br_src = $dir.$br;
    $out .= Page::compass($x, $y);
    $out .= <<EOF;
        <div id="map">
            <div id="drag">
	    <form action"=./" method="get">
                <input type="image" id="2.2" name="$tl" src="$tl_src" style="top:0px; left:0px;"><input type="image" id="3.2" name="$tr" src="$tr_src" style="top:0px; left:250px;"><br><input type="image" id="2.3" name="$bl" src="$bl_src" style="top:250px; left:0px;"><input type="image" id="3.3" name="$br" src="$br_src" style="top:250px; left:250px;">
            </form>
            </div>
        </div>
EOF
    return $out;
}
