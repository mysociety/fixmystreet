# FixMyStreet:Map::OSM::StreetView
# OSM StreetView maps on FixMyStreet.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::OSM::StreetView;

use Moo;
extends 'FixMyStreet::Map::OSM';

has '+zoom_levels' => ( default => 6 );

has '+map_type' => ( default => '' );

sub map_javascript { [
    '/vendor/OpenLayers/OpenLayers.fixmystreet.js',
    '/js/map-OpenLayers.js',
    '/js/map-streetview.js',
] }

has '+base_tile_url' => ( default => 'os.openstreetmap.org/sv' );

has '+copyright' => ( default => 'Contains OS data &copy; Crown copyright and database right 2016' );

1;
