#!/usr/bin/perl
#
# FixMyStreet:Map::OSM::CycleMap
# OSM CycleMap maps on FixMyStreet.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map;

use strict;
use mySociety::Web qw(ent);

sub header_js {
    return '
<script type="text/javascript" src="http://openlayers.org/api/OpenLayers.js"></script>
<script type="text/javascript" src="/js/map-OpenStreetMap.js"></script>
<script type="text/javascript" src="/js/OpenLayers.Projection.OrdnanceSurvey.js"></script>
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
    my $copyright = _('Map &copy; <a href="http://www.openstreetmap.org/">OpenStreetMap</a> and contributors, <a href="http://creativecommons.org/licenses/by-sa/2.0/">CC-BY-SA</a>');
    $out .= <<EOF;
<script type="text/javascript">
var fixmystreet = {
    'easting': $params{easting},
    'northing': $params{northing},
    'map_type': OpenLayers.Layer.OSM.CycleMap
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
