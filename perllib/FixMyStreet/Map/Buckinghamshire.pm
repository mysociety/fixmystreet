# FixMyStreet:Map::Buckinghamshire
# More JavaScript, for street assets

package FixMyStreet::Map::Buckinghamshire;
use base 'FixMyStreet::Map::FMS';

use strict;

sub map_javascript { [
    '/vendor/OpenLayers/OpenLayers.buckinghamshire.js',
    '/js/map-OpenLayers.js',
    '/js/map-bing-ol.js',
    '/js/map-fms.js',
    '/cobrands/fixmystreet/assets.js',
    '/cobrands/buckinghamshire/js.js',
] }

1;
