# FixMyStreet:Map::OSM::CycleMap
# OSM CycleMap maps on FixMyStreet.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::OSM::CycleMap;
use base 'FixMyStreet::Map::OSM';

use strict;

sub map_type {
    return 'OpenLayers.Layer.OSM.CycleMap';
}

sub base_tile_url {
    return 'tile.opencyclemap.org/cycle';
}

1;
