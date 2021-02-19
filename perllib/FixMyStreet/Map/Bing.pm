# FixMyStreet:Map::Bing
# Bing maps on FixMyStreet, using OpenLayers.

package FixMyStreet::Map::Bing;

use Moo;
extends 'FixMyStreet::Map::OSM';

has '+map_type' => ( default => '' );

has '+copyright' => ( default => '' );

sub map_javascript { [
    '/vendor/OpenLayers/OpenLayers.fixmystreet.js',
    '/js/map-OpenLayers.js',
    '/js/map-bing-ol.js',
] }

sub get_quadkey {
    my ($self, $x, $y, $z) = @_;
    my $key = '';
    for (my $i = $z; $i > 0; $i--) {
        my $digit = 0;
        my $mask = 1 << ($i - 1);
        $digit++ if ($x & $mask) != 0;
        $digit += 2 if ($y & $mask) != 0;
        $key .= $digit;
    }
    return $key;
}

my $road_base = '//%s.ssl.ak.dynamic.tiles.virtualearth.net/comp/ch/%s?mkt=en-US&it=G,L&src=t&shading=hill&og=969&n=z';
my $aerial_base = '//%s.ssl.ak.dynamic.tiles.virtualearth.net/comp/ch/%s?mkt=en-US&it=A,G,L&src=t&og=969&n=z';

sub map_tiles {
    my ( $self, %params ) = @_;
    my ( $x, $y, $z ) = ( $params{x_tile}, $params{y_tile}, $params{zoom_act} );
    my $tile_base = $params{aerial} ? $aerial_base : $road_base;
    return [
        sprintf($tile_base, 't0', $self->get_quadkey($x-1, $y-1, $z)),
        sprintf($tile_base, 't1', $self->get_quadkey($x,   $y-1, $z)),
        sprintf($tile_base, 't2', $self->get_quadkey($x-1, $y,   $z)),
        sprintf($tile_base, 't3', $self->get_quadkey($x,   $y,   $z)),
    ];
}

1;
