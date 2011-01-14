#!/usr/bin/perl
#
# FixMyStreet:Map::TilmaXY
# Using tilma.mysociety.org but accessing images directly.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map;

use strict;

use constant TILE_WIDTH => 250;
use constant TIF_SIZE_M => 5000;
use constant TIF_SIZE_PX => 5000;
use constant SCALE_FACTOR => TIF_SIZE_M / (TIF_SIZE_PX / TILE_WIDTH);
use constant TILE_TYPE => 'streetview';

sub header_js {
    return '
<script type="text/javascript" src="http://openlayers.org/api/OpenLayers.js"></script>
<script type="text/javascript" src="/js/map-tilma-ol.js"></script>
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
    my $tile_width = TILE_WIDTH;
    my $tile_type = TILE_TYPE;
    my $sf = SCALE_FACTOR / TILE_WIDTH;
    my $copyright = _('Map contains Ordnance Survey data &copy; Crown copyright and database right 2010.');
    $out .= <<EOF;
<script type="text/javascript">
var fixmystreet = {
    'tilewidth': $tile_width,
    'tileheight': $tile_width,
    'easting': $params{easting},
    'northing': $params{northing},
    'tile_type': '$tile_type',
    'maxResolution': $sf
};
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
