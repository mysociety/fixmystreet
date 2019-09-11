# FixMyStreet:Map::OSM::MapTiler
# OSM MapTiler maps on FixMyStreet.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::OSM::MapTiler;
use base 'FixMyStreet::Map::OSM';

use strict;

sub map_type { 'OpenLayers.Layer.OSM.MapTiler' }

sub base_tile_url { 'api.maptiler.com/maps/uk-openzoomstack-road/256' }

sub map_tiles {
    my ( $self, %params ) = @_;
    my ( $x, $y, $z ) = ( $params{x_tile}, $params{y_tile}, $params{zoom_act} );
    my $tile_url = $self->base_tile_url();
    return [
        "https://$tile_url/$z/" . ($x - 1) . "/" . ($y - 1) . ".png?key=kCrAT2nFkB6vTrvOtf1n",
        "https://$tile_url/$z/$x/" . ($y - 1) . ".png?key=kCrAT2nFkB6vTrvOtf1n",
        "https://$tile_url/$z/" . ($x - 1) . "/$y.png?key=kCrAT2nFkB6vTrvOtf1n",
        "https://$tile_url/$z/$x/$y.png?key=kCrAT2nFkB6vTrvOtf1n",
    ];
}


1;
