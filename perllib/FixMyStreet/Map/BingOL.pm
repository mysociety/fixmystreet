#!/usr/bin/perl
#
# FixMyStreet:Map::BingOL
# Bing maps on FixMyStreet, using OpenLayers.
#
# Copyright (c) 2011 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::BingOL;

use strict;
use mySociety::Gaze;

sub header_js {
    return '
<!-- <script type="text/javascript" src="http://ecn.dev.virtualearth.net/mapcontrol/mapcontrol.ashx?v=7.0&mkt=en-GB"></script> -->
<script type="text/javascript" src="/jslib/OpenLayers-2.10/OpenLayers.js"></script>
<script type="text/javascript" src="/js/map-OpenLayers.js"></script>
<script type="text/javascript" src="/js/map-bing-ol.js"></script>
';
}

# display_map C PARAMS
# PARAMS include:
# latitude, longitude for the centre point of the map
# CLICKABLE is set if the map is clickable
# PINS is array of pins to show, location and colour
sub display_map {
    my ($self, $c, %params) = @_;

    my $dist = mySociety::Gaze::get_radius_containing_population( $params{latitude}, $params{longitude}, 200_000 );
    my $zoom = 2;
    $zoom = 3 if $dist < 10;

    $c->stash->{map} = {
        %params,
        type => 'osm',
        zoom => $zoom,
        map_type => '""', # Is set by the JavaScript
        copyright => _('Map contains Ordnance Survey data &copy; Crown copyright and database right 2010. Microsoft'),
    };
}

1;
