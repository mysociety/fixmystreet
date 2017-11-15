# FixMyStreet:Map::Angus
# More JavaScript, for street assets

package FixMyStreet::Map::Angus;
use base 'FixMyStreet::Map::FMS';

use strict;

sub map_javascript { [
    '/vendor/OpenLayers/OpenLayers.angus.js',
    '/js/map-OpenLayers.js',
    '/js/map-bing-ol.js',
    '/js/map-fms.js',
    '/cobrands/fixmystreet/assets.js',
    '/cobrands/angus/js.js',
] }

1;
