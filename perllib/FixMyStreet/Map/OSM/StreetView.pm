# FixMyStreet:Map::OSM::StreetView
# OSM StreetView maps on FixMyStreet.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::OSM::StreetView;
use base 'FixMyStreet::Map::OSM';

use strict;

sub map_type {
    return '""';
}

sub map_template {
    return 'osm-streetview';
}

sub base_tile_url {
    return 'os.openstreetmap.org/sv';
}

sub copyright {
}

1;
