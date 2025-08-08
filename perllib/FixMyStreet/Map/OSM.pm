# FixMyStreet:Map::OSM
# OSM maps on FixMyStreet.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::OSM;

use Moo;
extends 'FixMyStreet::Map::Base';

use Math::Trig;
use Utils;

has map_type => ( is => 'ro', default => 'OpenLayers.Layer.OSM.Mapnik' );

has map_template => ( is => 'ro', default => 'osm' );

sub map_javascript { [
    '/vendor/OpenLayers/OpenLayers.wfs.js',
    '/js/map-OpenLayers.js',
    FixMyStreet->config('BING_MAPS_API_KEY') ? ('/js/map-bing-ol.js') : (),
    '/js/map-OpenStreetMap.js',
] }

sub map_tiles {
    my ( $self, %params ) = @_;
    my ( $x, $y, $z ) = ( $params{x_tile}, $params{y_tile}, $params{zoom_act} );
    my $tile_url;
    my $aerial_url = $self->cobrand->call_hook('has_aerial_maps');
    if ($params{aerial} && $aerial_url) {
        $tile_url = $aerial_url;
    } else {
        $tile_url = $self->base_tile_url();
    }
    return [
        "https://$tile_url/$z/" . ($x - 1) . "/" . ($y - 1) . ".png",
        "https://$tile_url/$z/$x/" . ($y - 1) . ".png",
        "https://$tile_url/$z/" . ($x - 1) . "/$y.png",
        "https://$tile_url/$z/$x/$y.png",
    ];
}

has base_tile_url => ( is => 'ro', default => 'tile.openstreetmap.org' );

has copyright => ( is => 'lazy', default => sub {
    _('&copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors');
});

sub generate_map_data {
    my ($self, %params) = @_;

    my $zoom_params = $self->calculate_zoom(%params);
    $params{zoom_act} = $zoom_params->{zoom_act};

    ($params{x_tile}, $params{y_tile}) = $self->latlon_to_tile_with_adjust($params{latitude}, $params{longitude}, $zoom_params->{zoom_act});

    foreach my $pin (@{$params{pins}}) {
        ($pin->{px}, $pin->{py}) = $self->latlon_to_px($pin->{latitude}, $pin->{longitude}, $params{x_tile}, $params{y_tile}, $zoom_params->{zoom_act});
    }

    my $aerial_url = $self->cobrand->call_hook('has_aerial_maps');
    return {
        %params,
        %$zoom_params,
        type => $self->map_template(),
        map_type => $self->map_type(),
        tiles => $self->map_tiles( %params ),
        copyright => $self->copyright(),
        $aerial_url ? (aerial_url => "https://$aerial_url") : (),
        compass => $self->compass( $params{x_tile}, $params{y_tile}, $zoom_params->{zoom_act} ),
    };
}

sub compass {
    my ( $self, $x, $y, $z ) = @_;
    return {
        north => [ map { Utils::truncate_coordinate($_) } $self->tile_to_latlon( $x, $y-1, $z ) ],
        south => [ map { Utils::truncate_coordinate($_) } $self->tile_to_latlon( $x, $y+1, $z ) ],
        west  => [ map { Utils::truncate_coordinate($_) } $self->tile_to_latlon( $x-1, $y, $z ) ],
        east  => [ map { Utils::truncate_coordinate($_) } $self->tile_to_latlon( $x+1, $y, $z ) ],
        here  => [ map { Utils::truncate_coordinate($_) } $self->tile_to_latlon( $x, $y, $z ) ],
    };
}

# Given a lat/lon, convert it to OSM tile co-ordinates (precise).
sub latlon_to_tile($$$$) {
    my ($self, $lat, $lon, $zoom) = @_;
    my $x_tile = ($lon + 180) / 360 * 2**$zoom;
    my $y_tile = (1 - log(tan(deg2rad($lat)) + sec(deg2rad($lat))) / pi) / 2 * 2**$zoom;
    return ( $x_tile, $y_tile );
}

# Given a lat/lon, convert it to OSM tile co-ordinates (nearest actual tile,
# adjusted so the point will be near the centre of a 2x2 tiled map).
sub latlon_to_tile_with_adjust($$$$) {
    my ($self, $lat, $lon, $zoom) = @_;
    my ($x_tile, $y_tile) = $self->latlon_to_tile($lat, $lon, $zoom);

    # Try and have point near centre of map
    if ($x_tile - int($x_tile) > 0.5) {
        $x_tile += 1;
    }
    if ($y_tile - int($y_tile) > 0.5) {
        $y_tile += 1;
    }

    return ( int($x_tile), int($y_tile) );
}

sub tile_to_latlon {
    my ($self, $x, $y, $zoom) = @_;
    my $n = 2 ** $zoom;
    my $lon = $x / $n * 360 - 180;
    my $lat = rad2deg(atan(sinh(pi * (1 - 2 * $y / $n))));
    return ( $lat, $lon );
}

# Given a lat/lon, convert it to pixel co-ordinates from the top left of the map
sub latlon_to_px($$$$$$) {
    my ($self, $lat, $lon, $x_tile, $y_tile, $zoom) = @_;
    my ($pin_x_tile, $pin_y_tile) = $self->latlon_to_tile($lat, $lon, $zoom);
    my $pin_x = tile_to_px($pin_x_tile, $x_tile);
    my $pin_y = tile_to_px($pin_y_tile, $y_tile);
    return ($pin_x, $pin_y);
}

# Convert tile co-ordinates to pixel co-ordinates from top left of map
# C is centre tile reference of displayed map
sub tile_to_px {
    my ($p, $c) = @_;
    $p = 256 * ($p - $c + 1);
    $p = int($p + .5 * ($p <=> 0));
    return $p;
}

sub click_to_tile {
    my ($pin_tile, $pin) = @_;
    $pin -= 256 while $pin > 256;
    $pin += 256 while $pin < 0;
    return $pin_tile + $pin / 256;
}

# Given some click co-ords (the tile they were on, and where in the
# tile they were), convert to WGS84 and return.
# XXX Note use of min_zoom_level here.
sub click_to_wgs84 {
    my ($cls, $c, $pin_tile_x, $pin_x, $pin_tile_y, $pin_y) = @_;
    my $self = $cls->new(
        latitude => $c->get_param('latitude'),
        longitude => $c->get_param('longitude'),
    );
    my $tile_x = click_to_tile($pin_tile_x, $pin_x);
    my $tile_y = click_to_tile($pin_tile_y, $pin_y);
    my $zoom = $self->min_zoom_level + (defined $c->get_param('zoom') ? $c->get_param('zoom') : 3);
    my ($lat, $lon) = $self->tile_to_latlon($tile_x, $tile_y, $zoom);
    return ( $lat, $lon );
}

1;
