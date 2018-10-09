# FixMyStreet:Map::BathNES
# More JavaScript, for street assets

package FixMyStreet::Map::BathNES;
use base 'FixMyStreet::Map::OSM';

use strict;

sub map_javascript { [
    '/vendor/OpenLayers/OpenLayers.wfs.js',
    '/vendor/OpenLayers.Projection.OrdnanceSurvey.js',
    '/js/map-OpenLayers.js',
    '/js/map-OpenStreetMap.js',
    '/cobrands/fixmystreet-uk-councils/roadworks.js',
    '/cobrands/fixmystreet/assets.js',
    '/cobrands/bathnes/js.js',
    '/cobrands/bathnes/assets.js',
] }

1;
