# FixMyStreet:Map::Bing
# Bing maps on FixMyStreet, using OpenLayers.

package FixMyStreet::Map::Bing;
use base 'FixMyStreet::Map::OSM';

use strict;

sub map_type { '' }

sub map_javascript { [
    '/vendor/OpenLayers/OpenLayers.fixmystreet.js',
    '/js/map-OpenLayers.js',
    '/js/map-bing-ol.js',
] }

sub copyright { '' }

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

sub map_tile_base {
    '', "//ecn.%s.tiles.virtualearth.net/tiles/r%s.png?g=6570";
}

sub map_tiles {
    my ( $self, %params ) = @_;
    my ( $x, $y, $z ) = ( $params{x_tile}, $params{y_tile}, $params{zoom_act} );
    my ($tile_sep, $tile_base) = $self->map_tile_base;
    return [
        sprintf($tile_base, 't0', $self->get_quadkey($x-1, $y-1, $z)),
        sprintf($tile_base, 't1', $self->get_quadkey($x,   $y-1, $z)),
        sprintf($tile_base, 't2', $self->get_quadkey($x-1, $y,   $z)),
        sprintf($tile_base, 't3', $self->get_quadkey($x,   $y,   $z)),
    ];
}

1;
