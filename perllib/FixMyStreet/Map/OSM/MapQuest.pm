# FixMyStreet:Map::OSM::CycleMap
# OSM CycleMap maps on FixMyStreet.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::OSM::MapQuest;
use base 'FixMyStreet::Map::OSM';

use strict;

sub map_type {
    return 'OpenLayers.Layer.OSM.MapQuestOpen';
}

sub map_template {
    return 'mapquest-attribution';
}

sub map_tiles {
    my ( $self, %params ) = @_;
    my ( $x, $y, $z ) = ( $params{x_tile}, $params{y_tile}, $params{zoom_act} );
    my $tile_url = $self->base_tile_url();
    return [
        "http://otile1.$tile_url/$z/" . ($x - 1) . "/" . ($y - 1) . ".png",
        "http://otile2.$tile_url/$z/$x/" . ($y - 1) . ".png",
        "http://otile3.$tile_url/$z/" . ($x - 1) . "/$y.png",
        "http://otile4.$tile_url/$z/$x/$y.png",
    ];
}

sub base_tile_url {
    return 'mqcdn.com/tiles/1.0.0/map/';
}

1;
