# FixMyStreet:Map::FMS
# Bing and OS StreetView maps on FixMyStreet, using OpenLayers.
#
# Copyright (c) 2011 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::FMS;
use base 'FixMyStreet::Map::Bing';

use strict;

sub map_template { 'fms' }

sub map_javascript { [
    '/vendor/OpenLayers/OpenLayers.wfs.js',
    '/js/map-OpenLayers.js',
    '/js/map-bing-ol.js',
    '/js/map-fms.js',
] }

sub map_tile_base {
    '-', "//%stilma.mysociety.org/oml/%d/%d/%d.png";
}

sub map_tiles {
    my ( $self, %params ) = @_;
    my ( $x, $y, $z ) = ( $params{x_tile}, $params{y_tile}, $params{zoom_act} );
    my $ni = in_northern_ireland_box( $params{latitude}, $params{longitude} );
    if (!$ni && $z >= 16) {
        my ($tile_sep, $tile_base) = $self->map_tile_base;
        return [
            sprintf($tile_base, 'a' . $tile_sep, $z, $x-1, $y-1),
            sprintf($tile_base, 'b' . $tile_sep, $z, $x, $y-1),
            sprintf($tile_base, 'c' . $tile_sep, $z, $x-1, $y),
            sprintf($tile_base, '', $z, $x, $y),
        ];
    } else {
        my $key = FixMyStreet->config('BING_MAPS_API_KEY');
        my $url = "g=6570";
        $url .= "&productSet=mmOS&key=$key" if $z > 11 && !$ni;
        return [
            "//ecn.t0.tiles.virtualearth.net/tiles/r" . $self->get_quadkey($x-1, $y-1, $z) . ".png?$url",
            "//ecn.t1.tiles.virtualearth.net/tiles/r" . $self->get_quadkey($x,   $y-1, $z) . ".png?$url",
            "//ecn.t2.tiles.virtualearth.net/tiles/r" . $self->get_quadkey($x-1, $y,   $z) . ".png?$url",
            "//ecn.t3.tiles.virtualearth.net/tiles/r" . $self->get_quadkey($x,   $y,   $z) . ".png?$url",
        ];
    }
}

sub in_northern_ireland_box {
    my ($lat, $lon) = @_;
    return 1 if $lat >= 54.015 && $lat <= 55.315 && $lon >= -8.18 && $lon <= -5.415;
    return 0;
}

1;
