#!/usr/bin/perl
#
# FixMyStreet:Map
# Adding the ability to have different maps on FixMyStreet.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map;

use strict;

use Problems;
use Cobrand;
use mySociety::Config;
use mySociety::Gaze;
use mySociety::GeoUtil;
use mySociety::Locale;
use mySociety::Web qw(ent NewURL);

# Run on module boot up
load();

# This is yucky, but no-one's taught me a better way
sub load {
    my $type = mySociety::Config::get('MAP_TYPE');
    my $class = "FixMyStreet::Map::$type";
    eval "use $class";
}

sub header {
    my ($q, $type) = @_;
    return '' unless $type;

    my $cobrand = Page::get_cobrand($q);
    my $cobrand_form_elements = Cobrand::form_elements($cobrand, 'mapForm', $q);
    my $form_action = Cobrand::url($cobrand, '', $q);
    my $encoding = '';
    $encoding = ' enctype="multipart/form-data"' if $type==2;
    my $pc = $q->param('pc') || '';
    my $pc_enc = ent($pc);
    return <<EOF;
<form action="$form_action" method="post" name="mapForm" id="mapForm"$encoding>
<input type="hidden" name="submit_map" value="1">
<input type="hidden" name="pc" value="$pc_enc">
$cobrand_form_elements
EOF
}

sub map_features {
    my ($q, $easting, $northing, $interval) = @_;

    my $min_e = $easting - 500;
    my $min_n = $northing - 500;
    my $mid_e = $easting;
    my $mid_n = $northing;
    my $max_e = $easting + 500;
    my $max_n = $northing + 500;

    # list of problems aoround map can be limited, but should show all pins
    my ($around_map, $around_map_list);
    if (my $around_limit = Cobrand::on_map_list_limit(Page::get_cobrand($q))) {
        $around_map_list = Problems::around_map($min_e, $max_e, $min_n, $max_n, $interval, $around_limit);
        $around_map = Problems::around_map($min_e, $max_e, $min_n, $max_n, $interval, undef);
    } else {
        $around_map = $around_map_list = Problems::around_map($min_e, $max_e, $min_n, $max_n, $interval, undef);
    }

    my ($lat, $lon) = mySociety::GeoUtil::national_grid_to_wgs84($mid_e, $mid_n, 'G');

    my $dist;
    mySociety::Locale::in_gb_locale {
        $dist = mySociety::Gaze::get_radius_containing_population($lat, $lon, 200000);
    };
    $dist = int($dist*10+0.5)/10;

    my $limit = 20;
    my @ids = map { $_->{id} } @$around_map_list;
    my $nearby = Problems::nearby($dist, join(',', @ids), $limit, $mid_lat, $mid_lon, $interval);

    return ($around_map, $around_map_list, $nearby, $dist);
}

sub compass ($$$) {
    my ($q, $x, $y) = @_;
    my @compass;
    for (my $i=$x-1; $i<=$x+1; $i++) {
        for (my $j=$y-1; $j<=$y+1; $j++) {
            $compass[$i][$j] = NewURL($q, x=>$i, y=>$j);
        }
    }
    my $recentre = NewURL($q);
    my $host = Page::base_url_with_lang($q, undef);
    return <<EOF;
<table cellpadding="0" cellspacing="0" border="0" id="compass">
<tr valign="bottom">
<td align="right"><a rel="nofollow" href="${compass[$x-1][$y+1]}"><img src="$host/i/arrow-northwest.gif" alt="NW" width=11 height=11></a></td>
<td align="center"><a rel="nofollow" href="${compass[$x][$y+1]}"><img src="$host/i/arrow-north.gif" vspace="3" alt="N" width=13 height=11></a></td>
<td><a rel="nofollow" href="${compass[$x+1][$y+1]}"><img src="$host/i/arrow-northeast.gif" alt="NE" width=11 height=11></a></td>
</tr>
<tr>
<td><a rel="nofollow" href="${compass[$x-1][$y]}"><img src="$host/i/arrow-west.gif" hspace="3" alt="W" width=11 height=13></a></td>
<td align="center"><a rel="nofollow" href="$recentre"><img src="$host/i/rose.gif" alt="Recentre" width=35 height=34></a></td>
<td><a rel="nofollow" href="${compass[$x+1][$y]}"><img src="$host/i/arrow-east.gif" hspace="3" alt="E" width=11 height=13></a></td>
</tr>
<tr valign="top">
<td align="right"><a rel="nofollow" href="${compass[$x-1][$y-1]}"><img src="$host/i/arrow-southwest.gif" alt="SW" width=11 height=11></a></td>
<td align="center"><a rel="nofollow" href="${compass[$x][$y-1]}"><img src="$host/i/arrow-south.gif" vspace="3" alt="S" width=13 height=11></a></td>
<td><a rel="nofollow" href="${compass[$x+1][$y-1]}"><img src="$host/i/arrow-southeast.gif" alt="SE" width=11 height=11></a></td>
</tr>
</table>
EOF
}

1;
