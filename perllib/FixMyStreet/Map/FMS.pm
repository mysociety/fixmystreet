# FixMyStreet:Map::FMS
# Bing and OS StreetView maps on FixMyStreet, using OpenLayers.
#
# Copyright (c) 2011 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::FMS;

use Moo;
extends 'FixMyStreet::Map::Bing';

has '+zoom_levels' => ( default => 6 );

has '+map_template' => ( default => 'fms' );

sub map_javascript { [
    '/vendor/OpenLayers/OpenLayers.wfs.js',
    '/js/map-OpenLayers.js',
    '/js/map-bing-ol.js',
    '/js/map-fms.js',
] }

has '+base_tile_url' => ( default => '//%stilma.mysociety.org/oml' );

has map_tile_prefix  => ( is => 'ro', default => sub { [ 'a-', 'b-', 'c-', '' ] } );

sub map_tiles {
    my ( $self, %params ) = @_;
    my ( $x, $y, $z ) = ( $params{x_tile}, $params{y_tile}, $params{zoom_act} );
    my $ni = in_northern_ireland_box( $params{latitude}, $params{longitude} );
    if ($params{aerial} || $ni || $z <= 11) {
        return $self->SUPER::map_tiles(%params);
    } elsif ($z >= 16) {
        my $tile_base = $self->base_tile_url . '/%d/%d/%d.png';
        my $prefixes = $self->map_tile_prefix;
        my @urls;
        for (my $i=0; $i<4; $i++) {
            my @args = ($z, $x-1+($i%2), $y-1+int($i/2));
            unshift @args, $prefixes->[$i] if defined $prefixes->[$i];
            push @urls, sprintf($tile_base, @args);
        }
        return \@urls;
    } elsif ($z > 11) {
        my $key = FixMyStreet->config('BING_MAPS_API_KEY');
        my $base = "//ecn.%s.tiles.virtualearth.net/tiles/r%s?g=8702&lbl=l1&productSet=mmOS&key=$key";
        return [
            sprintf($base, "t0", $self->get_quadkey($x-1, $y-1, $z)),
            sprintf($base, "t1", $self->get_quadkey($x,   $y-1, $z)),
            sprintf($base, "t2", $self->get_quadkey($x-1, $y,   $z)),
            sprintf($base, "t3", $self->get_quadkey($x,   $y,   $z)),
        ];
    }
}

sub in_northern_ireland_box {
    my ($lat, $lon) = @_;
    return 1 if $lat && $lon && $lat >= 54.015 && $lat <= 55.315 && $lon >= -8.18 && $lon <= -5.415;
    return 0;
}

1;
