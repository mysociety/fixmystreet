package FixMyStreet::Map::OSM::Cymru;

use Moo;
extends 'FixMyStreet::Map::OSM';

has '+map_type' => ( default => 'OpenLayers.Layer.OSM.Cymru' );

has '+zoom_levels' => ( default => 6 );

sub map_javascript { [
    '/vendor/OpenLayers/OpenLayers.wfs.js',
    '/js/map-OpenLayers.js',
    FixMyStreet->config('BING_MAPS_API_KEY') ? ('/js/map-bing-ol.js') : (),
    '/js/map-OSMCymru.js',
] }

sub map_tiles {
    my ( $self, %params ) = @_;
    return FixMyStreet::Map::Bing->map_tiles(%params) if $params{aerial};
    my ( $x, $y, $z ) = ( $params{x_tile}, $params{y_tile}, $params{zoom_act} );
    my $tile_url = "//tilma.mysociety.org/proxy/osm-cymru";
    return [
        "$tile_url/$z/" . ($x - 1) . "/" . ($y - 1) . ".png",
        "$tile_url/$z/" . ($y - 1) . ".png",
        "$tile_url/$z/" . ($x - 1) . "/$y.png",
        "$tile_url/$z/$x/$y.png",
    ];
}

1;
