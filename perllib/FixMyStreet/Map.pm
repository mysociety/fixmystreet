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
use mySociety::GeoUtil qw(national_grid_to_wgs84);
use mySociety::Locale;
use mySociety::Web qw(ent NewURL);
use Utils;

# Run on module boot up
load();

# This is yucky, but no-one's taught me a better way
sub load {
    my $type  = mySociety::Config::get('MAP_TYPE');
    my $class = "FixMyStreet::Map::$type";
    eval "use $class";

    # If we have an error die as it is a compile error rather than runtime error
    die $@ if $@;
}

sub header {
    my ( $q, $type ) = @_;
    return '' unless $type;

    my $cobrand = Page::get_cobrand($q);
    my $cobrand_form_elements =
      Cobrand::form_elements( $cobrand, 'mapForm', $q );
    my $form_action = Cobrand::url( $cobrand, '', $q );
    my $encoding = '';
    $encoding = ' enctype="multipart/form-data"' if $type == 2;
    my $pc = $q->param('pc') || '';
    my $pc_enc = ent($pc);
    return <<EOF;
<form action="$form_action" method="post" name="mapForm" id="mapForm"$encoding>
<input type="hidden" name="submit_map" value="1">
<input type="hidden" name="pc" value="$pc_enc">
$cobrand_form_elements
EOF
}

=head2 map_features_easting_northing

Wrapper around map_features which does the easting, northing to lat, lon
conversion.

=cut

sub map_features_easting_northing {
    my ( $q, $easting, $northing, $interval ) = @_;
    my ( $lat, $lon ) = Utils::convert_en_to_latlon( $easting, $northing );
    return map_features( $q, $lat, $lon, $interval );
}

sub map_features {
    my ( $q, $lat, $lon, $interval ) = @_;

   # TODO - be smarter about calculating the surrounding square
   # use deltas that are roughly 500m in the UK - so we get a 1 sq km search box
    my $lat_delta = 0.00438;
    my $lon_delta = 0.00736;

    my $min_lat = $lat - $lat_delta;
    my $max_lat = $lat + $lat_delta;

    my $min_lon = $lon - $lon_delta;
    my $max_lon = $lon + $lon_delta;

    # list of problems around map can be limited, but should show all pins
    my $around_limit    #
      = Cobrand::on_map_list_limit( Page::get_cobrand($q) ) || undef;

    my @around_args = ( $min_lat, $max_lat, $min_lon, $max_lon, $interval );
    my $around_map_list = Problems::around_map( @around_args, $around_limit );
    my $around_map      = Problems::around_map( @around_args, undef );

    my $dist;
    mySociety::Locale::in_gb_locale {
        $dist =
          mySociety::Gaze::get_radius_containing_population( $lat, $lon,
            200000 );
    };
    $dist = int( $dist * 10 + 0.5 ) / 10;

    my $limit  = 20;
    my @ids    = map { $_->{id} } @$around_map_list;
    my $nearby = Problems::nearby( $dist, join( ',', @ids ),
        $limit, $lat, $lon, $interval );

    return ( $around_map, $around_map_list, $nearby, $dist );
}

sub compass ($$$) {
    my ( $q, $x, $y ) = @_;
    my @compass;
    for ( my $i = $x - 1 ; $i <= $x + 1 ; $i++ ) {
        for ( my $j = $y - 1 ; $j <= $y + 1 ; $j++ ) {
            $compass[$i][$j] = NewURL( $q, x => $i, y => $j );
        }
    }
    my $recentre = NewURL($q);
    my $host = Page::base_url_with_lang( $q, undef );
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
