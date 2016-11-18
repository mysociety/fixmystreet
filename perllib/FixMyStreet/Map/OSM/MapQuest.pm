# FixMyStreet:Map::OSM::CycleMap
# OSM CycleMap maps on FixMyStreet.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::OSM::MapQuest;
use base 'FixMyStreet::Map::OSM';

use strict;

sub map_type { 'OpenLayers.Layer.OSM.MapQuestOpen' }

sub map_template { 'mapquest-attribution' }

sub map_tiles {
    my ( $self, %params ) = @_;
    my ( $x, $y, $z ) = ( $params{x_tile}, $params{y_tile}, $params{zoom_act} );
    my $tile_url = $self->base_tile_url();
    return [
        "https://otile1-s.$tile_url/$z/" . ($x - 1) . "/" . ($y - 1) . ".png",
        "https://otile2-s.$tile_url/$z/$x/" . ($y - 1) . ".png",
        "https://otile3-s.$tile_url/$z/" . ($x - 1) . "/$y.png",
        "https://otile4-s.$tile_url/$z/$x/$y.png",
    ];
}

sub base_tile_url {
    return 'mqcdn.com/tiles/1.0.0/map/';
}

sub copyright {
    'Data, imagery and map information provided by <a href="https://www.mapquest.com/">MapQuest</a> <img src="https://developer.mapquest.com/sites/default/files/mapquest/osm/mq_logo.png" />, <a href="https://openstreetmap.org/">OpenStreetMap</a> and contributors, <a href="https://opendatacommons.org/licenses/odbl/">ODbL</a>'
}

1;
