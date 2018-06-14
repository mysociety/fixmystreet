# FixMyStreet:Map::Lincolnshire
# More JavaScript, for street assets

package FixMyStreet::Map::Lincolnshire;
use base 'FixMyStreet::Map::OSM';

use strict;

sub map_javascript { [
    '/vendor/OpenLayers/OpenLayers.buckinghamshire.js', # TODO change after FMS PR #2055 merged
    '/vendor/OpenLayers.Projection.OrdnanceSurvey.js',
    '/js/map-OpenLayers.js',
    '/js/map-OpenStreetMap.js',
    '/cobrands/fixmystreet-uk-councils/roadworks.js',
    '/cobrands/fixmystreet/assets.js',
    '/cobrands/lincolnshire/js.js',
] }

1;
