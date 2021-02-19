# FixMyStreet:Map::OSM::CycleMap
# OSM CycleMap maps on FixMyStreet.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::OSM::CycleMap;

use Moo;
extends 'FixMyStreet::Map::OSM';

has '+map_type' => ( default => 'OpenLayers.Layer.OSM.CycleMap' );

has '+base_tile_url' => ( default => 'tile.opencyclemap.org/cycle' );

1;
