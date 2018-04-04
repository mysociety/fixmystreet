# FixMyStreet:Map::Bromley
# Bromley have slightly different tiles, with trees etc.
#
# Copyright (c) 2012 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::Bromley;
use base 'FixMyStreet::Map::FMS';

use strict;

sub map_javascript { [
    '/vendor/OpenLayers/OpenLayers.wfs.js',
    '/js/map-OpenLayers.js',
    '/js/map-bing-ol.js',
    '/js/map-fms.js',
    '/cobrands/fixmystreet/assets.js',
    '/cobrands/bromley/map.js',
    '/cobrands/bromley/assets.js',
] }

sub map_tile_base {
    '-', "https://%sfix.bromley.gov.uk/tilma/%d/%d/%d.png";
}

1;
