package FixMyStreet::Map::CheshireEast;
use base 'FixMyStreet::Map::OSM';

use strict;
use Utils;

use constant MIN_ZOOM_LEVEL => 7;

sub map_javascript { [
    '/vendor/OpenLayers/OpenLayers.wfs.js',
    '/js/map-OpenLayers.js',
    '/js/map-cheshireeast.js',
] }

sub tile_parameters { {
    origin_x => -3276800,
    origin_y => 3276800,
} }

sub resolutions { (
    1792.003584007169,
    896.0017920035843,
    448.0008960017922,
    224.0004480008961,
    112.000224000448,
    56.000112000224014,
    28.000056000111993,
    14.000028000056004,
    7.000014000028002,
    2.8000056000112004,
    1.4000028000056002,
    0.7000014000028001,
    0.35000070000140004,
    0.14000028000056003,
) }

my $url = 'https://maps-cache.cheshiresharedservices.gov.uk/maps/?wmts/CE_OS_AllBasemaps_COLOUR/oscce_grid/%d/%d/%d.jpeg&KEY=3a3f5c60eca1404ea114e6941c9d3895';

sub map_tiles {
    my ( $self, %params ) = @_;
    my ( $x, $y, $z ) = ( $params{x_tile}, $params{y_tile}, $params{zoom_act} );
    return [
        sprintf($url, $z, $x-1, $y-1),
        sprintf($url, $z, $x, $y-1),
        sprintf($url, $z, $x-1, $y),
        sprintf($url, $z, $x, $y),
    ];
}

sub latlon_to_tile($$$$) {
    my ($self, $lat, $lon, $zoom) = @_;
    my ($x, $y) = eval { Utils::convert_latlon_to_en($lat, $lon) };
    my $tile_params = $self->tile_parameters;
    my $res = ($self->resolutions)[$zoom];
    my $fx = ( $x - $tile_params->{origin_x} ) / ($res * 256);
    my $fy = ( $tile_params->{origin_y} - $y ) / ($res * 256);
    return ( $fx, $fy );
}

sub tile_to_latlon {
    my ($self, $fx, $fy, $zoom) = @_;
    my $tile_params = $self->tile_parameters;
    my $res = ($self->resolutions)[$zoom];
    my $x = $fx * $res * 256 + $tile_params->{origin_x};
    my $y = $tile_params->{origin_y} - $fy * $res * 256;
    my ($lat, $lon) = Utils::convert_en_to_latlon($x, $y);
    return ( $lat, $lon );
}

1;
