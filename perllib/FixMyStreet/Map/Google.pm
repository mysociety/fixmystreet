#!/usr/bin/perl
#
# FixMyStreet:Map::Google
# Google maps on FixMyStreet.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map;

use strict;
use mySociety::GeoUtil;
use mySociety::Web qw(ent);

sub header_js {
    return '
<script type="text/javascript" src="http://maps.google.com/maps/api/js?sensor=false"></script>
<script type="text/javascript" src="/js/map-google.js"></script>
';
}

# display_map Q PARAMS
# PARAMS include:
# EASTING, NORTHING for the centre point of the map
# TYPE is 1 if the map is clickable, 2 if clickable and has a form upload,
#     0 if not clickable
# PINS is array of pins to show, location and colour
# PRE/POST are HTML to show above/below map
sub display_map {
    my ($q, %params) = @_;
    $params{pre} ||= '';
    $params{post} ||= '';

    foreach my $pin (@{$params{pins}}) {
    }

    my $out = FixMyStreet::Map::header($q, $params{type});
    my ($lat, $lon) = mySociety::GeoUtil::national_grid_to_wgs84($params{easting}, $params{northing}, 'G');
    my $copyright = _('Map contains Ordnance Survey data &copy; Crown copyright and database right 2010.');
    $out .= <<EOF;
<script type="text/javascript">
var fixmystreet = {
    'lat': $lat,
    'lon': $lon
}
</script>
<div id="map_box">
    $params{pre}
    <div id="map"></div>
    <p id="copyright">$copyright</p>
    $params{post}
</div>
<div id="side">
EOF
    return $out;
}

sub display_map_end {
    my ($type) = @_;
    my $out = '</div>';
    $out .= '</form>' if ($type);
    return $out;
}

sub display_pin {
}

sub map_pins {
}

1;
