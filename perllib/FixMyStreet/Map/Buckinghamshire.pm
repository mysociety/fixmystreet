# FixMyStreet:Map::Buckinghamshire
# More JavaScript, for street assets

package FixMyStreet::Map::Buckinghamshire;
use base 'FixMyStreet::Map::OSM';

use strict;

sub map_javascript { [
    '/vendor/OpenLayers/OpenLayers.wfs.js',
    '/vendor/OpenLayers.Projection.OrdnanceSurvey.js',
    '/js/map-OpenLayers.js',
    '/js/map-OpenStreetMap.js',
    '/cobrands/fixmystreet-uk-councils/roadworks.js',
    '/cobrands/fixmystreet/assets.js',
    '/cobrands/buckinghamshire/js.js',
    '/cobrands/buckinghamshire/assets.js',
] }

1;
