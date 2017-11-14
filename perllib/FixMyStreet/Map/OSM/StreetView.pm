# FixMyStreet:Map::OSM::StreetView
# OSM StreetView maps on FixMyStreet.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::OSM::StreetView;
use base 'FixMyStreet::Map::OSM';

use strict;

sub map_type { '' }

sub map_javascript { [
    '/vendor/OpenLayers/OpenLayers.fixmystreet.js',
    '/js/map-OpenLayers.js',
    '/js/map-streetview.js',
] }

sub base_tile_url {
    return 'os.openstreetmap.org/sv';
}

sub copyright {
    'Contains OS data &copy; Crown copyright and database right 2016';
}

1;
