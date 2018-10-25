package FixMyStreet::Map::HighwaysUK;
use base 'FixMyStreet::Map::OSM';

use strict;

sub map_javascript { [
    '/vendor/OpenLayers/OpenLayers.wfs.js',
    '/js/map-OpenLayers.js',
    '/cobrands/borsetshire/map.js',
] }

sub map_tiles {
    my ( $self, %params ) = @_;
    my ( $x, $y, $z ) = ( $params{x_tile}, $params{y_tile}, $params{zoom_act} );
    return [
        "/tilma/$z/" . ($x - 1) . "/" . ($y - 1) . ".png",
        "/tilma/$z/$x/" . ($y - 1) . ".png",
        "/tilma/$z/" . ($x - 1) . "/$y.png",
        "/tilma/$z/$x/$y.png",
    ];
}

1;
