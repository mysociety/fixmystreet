#!/usr/bin/perl
#
# FixMyStreet:Map::Tilma::1_10k_OL
# Using tilma.mysociety.org with OpenLayers
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::Tilma::OL::1_10k;

use strict;

use constant TILE_WIDTH => 254;
use constant TIF_SIZE_M => 5000;
use constant TIF_SIZE_PX => 7874;
use constant SCALE_FACTOR => TIF_SIZE_M / (TIF_SIZE_PX / TILE_WIDTH);
use constant TILE_TYPE => '10k-full';

sub header_js {
    return '
<script type="text/javascript" src="/jslib/OpenLayers-2.10/OpenLayers.js"></script>
<script type="text/javascript" src="/js/map-OpenLayers.js"></script>
<script type="text/javascript" src="/js/map-tilma-ol.js"></script>
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
    my ($self, $q, %params) = @_;
    $params{pre} ||= '';
    $params{post} ||= '';

    my @pins;
    foreach my $pin (@{$params{pins}}) {
        $pin->[3] ||= '';
        push @pins, "[ $pin->[0], $pin->[1], '$pin->[2]', '$pin->[3]' ]";
    }
    my $pins_js = join(",\n", @pins);

    my $out = FixMyStreet::Map::header($q, $params{type});
    my $tile_width = TILE_WIDTH;
    my $tile_type = TILE_TYPE;
    my $sf = SCALE_FACTOR / TILE_WIDTH;
    my $copyright = _('&copy; Crown copyright. All rights reserved. Ministry of Justice 100037819&nbsp;2008.');
    $out .= <<EOF;
<input type="hidden" name="latitude" id="fixmystreet.latitude" value="$params{latitude}">
<input type="hidden" name="longitude" id="fixmystreet.longitude" value="$params{longitude}">
<script type="text/javascript">
var fixmystreet = {
    'tilewidth': $tile_width,
    'tileheight': $tile_width,
    'latitude': $params{latitude},
    'longitude': $params{longitude},
    'pins': [ $pins_js ],
    'tile_type': '$tile_type',
    'maxResolution': $sf
};
</script>
<div id="map_box">
    $params{pre}
    <div id="map">
        <div id="watermark"></div>
    </div>
    <p id="copyright">$copyright</p>
$params{post}
</div>
<div id="side">
EOF
    return $out;
}

1;
