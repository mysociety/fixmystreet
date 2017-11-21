# FixMyStreet:Map::BathNES
# More JavaScript, for street assets

package FixMyStreet::Map::BathNES;
use base 'FixMyStreet::Map::FMS';

use strict;

sub map_javascript { [
    '/vendor/OpenLayers/OpenLayers.bathnes.js',
    '/vendor/OpenLayers.Projection.OrdnanceSurvey.js',
    '/js/map-OpenLayers.js',
    '/js/map-bing-ol.js',
    '/js/map-fms.js',
    '/cobrands/fixmystreet/assets.js',
    '/cobrands/bathnes/js.js',
] }

1;