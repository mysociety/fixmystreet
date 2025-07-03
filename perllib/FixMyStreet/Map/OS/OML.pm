package FixMyStreet::Map::OS::OML;

use Moo;
extends 'FixMyStreet::Map::OSM';
with 'FixMyStreet::Map::OS::Base';

has map_tile_prefix  => ( is => 'ro', default => sub { [ 'a-', 'b-', 'c-', '' ] } );

has in_northern_ireland_box => ( is => 'lazy', default => sub {
    my $self = shift;
    my $lat = $self->latitude;
    my $lon = $self->longitude;
    return 1 if $lat && $lon && $lat >= 54.015 && $lat <= 55.315 && $lon >= -8.18 && $lon <= -5.415;
    return 0;
});

sub map_tiles {
    my ( $self, %params ) = @_;
    my ( $x, $y, $z ) = ( $params{x_tile}, $params{y_tile}, $params{zoom_act} );

    if ($params{aerial} || $self->in_northern_ireland_box) {
        return $self->SUPER::map_tiles(%params);
    }

    if (!$self->premium && $self->oml_zoom_switch && $z >= $self->oml_zoom_switch) {
        my $tile_base = $self->oml_tile_url . '/%d/%d/%d.png';
        my $prefixes = $self->map_tile_prefix;
        my @urls;
        for (my $i=0; $i<4; $i++) {
            my @args = ($z, $x-1+($i%2), $y-1+int($i/2));
            unshift @args, $prefixes->[$i] if defined $prefixes->[$i];
            push @urls, sprintf($tile_base, @args);
        }
        return \@urls;
    }

    my $layer = $self->layer;
    if ($self->cobrand->feature('os_maps_leisure') && ($z == 7 || $z == 8)) {
        $layer = 'Leisure_27700';
    }
    my $tile_url = sprintf($self->os_tile_url, $layer);
    my $key = $self->key;
    return [
        "$tile_url/$z/" . ($x-1) . "/" . ($y-1) . ".png?key=$key",
        "$tile_url/$z/$x/" . ($y-1) . ".png?key=$key",
        "$tile_url/$z/" . ($x-1) . "/$y.png?key=$key",
        "$tile_url/$z/$x/$y.png?key=$key",
    ];
}

1;
