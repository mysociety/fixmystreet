# FixMyStreet:Map::FMS
# OSM / OS Maps / OML maps on FixMyStreet, using OpenLayers.
#
# Copyright (c) 2011 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::FMS;

use Moo;
extends 'FixMyStreet::Map::OS::OML';

has '+zoom_levels' => ( is => 'lazy', default => sub {
    $_[0]->premium ? 8 : 6
} );


has '+map_template' => ( default => 'fms' );

has '+copyright' => ( default => '' );

sub map_javascript { [
    '/vendor/OpenLayers/OpenLayers.wfs.js',
    '/js/map-OpenLayers.js',
    '/js/map-OpenStreetMap.js',
    '/js/map-bing-ol.js',
    '/js/map-fms.js',
] }

has oml_tile_url => ( is => 'ro', default => '//%stilma.mysociety.org/oml' );

has '+oml_zoom_switch' => ( default => 17 );

1;
