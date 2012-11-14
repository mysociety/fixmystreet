#!/usr/bin/perl
#
# FixMyStreet:Map::Zurich
# Zurich have their own tileserver serving aerial photos instead
# of street maps.
#
# Copyright (c) 2012 UK Citizens Online Democracy. All rights reserved.
# Email: steve@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::Zurich;
use base 'FixMyStreet::Map::FMS';

use strict;

sub map_type {
    return 'OpenLayers.Layer.WMTS_18';
}

sub map_tile_base {
    'http://www.wmts.stadt-zuerich.ch/Luftbild/MapServer/WMTS/tile/1.0.0/Luftbild';
}

# TODO - we need to use swiss coordinate system, projection: EPSG:4326ß

1;