#!/usr/bin/perl -w

# index.pl:
# Main code for BCI - not really.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: index.cgi,v 1.11 2006-09-20 16:12:06 matthew Exp $

use strict;
require 5.8.0;

# Horrible boilerplate to set up appropriate library paths.
use FindBin;
use lib "$FindBin::Bin/../perllib";
use lib "$FindBin::Bin/../../perllib";
use Error qw(:try);
use HTML::Entities;

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

    my $areas;
    my $error;
    try {
        $areas = mySociety::MaPit::get_voting_areas($pc);
    } catch RABX::Error with {
        my $e = shift;
        if ($e->value() == mySociety::MaPit::BAD_POSTCODE
            || $e->value() == mySociety::MaPit::POSTCODE_NOT_FOUND) {
            $error = 'That postcode was not recognised, sorry.';
        } else {
	    $e->throw();
	}
    };
    return front_page($error) if ($error);

    # Check for London Borough
    return front_page('I\'m afraid that postcode isn\'t in our covered area.') if (!$areas || !$areas->{LBO});

    # Check for Lewisham or Newham
    my $lbo = $areas->{LBO};
    return front_page('I\'m afraid that postcode isn\'t in our covered London boroughs.') unless ($lbo == 2510 || $lbo == 2492);

    my $area_info = mySociety::MaPit::get_voting_area_info($lbo);
    my $name = $area_info->{name};

    my $location = mySociety::MaPit::get_location($pc);

    my $out = <<EOF;
<h2>$name</h2>
<p>Now, please select the location of the problem on the map below.
Use the arrows to the left of the map to scroll around.</p>
EOF
    my @ps = $q->param;
    foreach (@ps) {
        my $x = $q->param($_) if /\.x$/;
        my $y = $q->param($_) if /\.y$/;
    }
    
    my $x = $q->param('x') || 628;
    my $y = $q->param('y') || 1724;
    my $dir = mySociety::Config::get('TILES_URL');
    my $tl = $x . '.' . $y;
    my $tr = ($x+1) . '.' . $y;
    my $bl = $x . '.' . ($y+1);
    my $br = ($x+1) . '.' . ($y+1);
    my $tl_src = $dir . $tl . '.png';
    my $tr_src = $dir . $tr . '.png';
    my $bl_src = $dir . $bl . '.png';
    my $br_src = $dir . $br . '.png';
    $pc = encode_entities($pc);
    $out .= <<EOF;
            <form action"=./" method="get">
    <div id="relativediv">
        <div id="map">
	    <input type="hidden" name="x" value="$x">
	    <input type="hidden" name="y" value="$y">
	    <input type="hidden" name="pc" value="$pc">
	    <input type="hidden" name="lbo" value="$lbo">
                <input type="image" id="2.2" name="$tl" src="$tl_src" style="top:0px; left:0px;"><input type="image" id="3.2" name="$tr" src="$tr_src" style="top:0px; left:250px;"><br><input type="image" id="2.3" name="$bl" src="$bl_src" style="top:250px; left:0px;"><input type="image" id="3.3" name="$br" src="$br_src" style="top:250px; left:250px;">
        </div>
EOF
    $out .= Page::compass($pc, $x, $y);
    $out .= <<EOF;
    <div>
    <h2>Current problems</h2>
    <ul id="current">
EOF
    my %current = (
        1 => 'Broken lamppost',
        2 => 'Shards of glass',
        3 => 'Abandoned car',
    );
    my %fixed = (
        4 => 'Broken lamppost',
        5 => 'Shards of glass',
        6 => 'Abandoned car',
    );
    foreach (sort keys %current) {
        my $px = int(rand(500)) - 6;
        my $py = int(rand(500)) - 20;
        $out .= '<li><a href="/?id=' . $_ . '">';
	$out .= '<img src="/i/pin_red.png" alt="Problem"';
	$out .= ' style="top:'.$py.'px; right:'.$px.'px">';
	$out .= $current{$_};
	$out .= '</a></li>';
    }
    $out .= <<EOF;
    </ul>
    <h2>Recently fixed problems</h2>
    <ul>
EOF
    foreach (sort keys %fixed) {
        $out .= '<li><a href="/?id=' . $_ . '">';
	#$out .= '<img src="/i/pin_red.png" alt="Problem">';
	$out .= $fixed{$_};
	$out .= '</a></li>';
    }
    $out .= <<EOF;
    </ul>
    </div>

</div>
            </form>

<p>If you cannot see a map &ndash; if you have images turned off,
or are using a text only browser, for example &ndash; please
<a href="./?skippedmap=1">skip this step</a> and we will ask you
to describe the location of your problem instead.</p>
EOF
    return $out;
}
