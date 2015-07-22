# FixMyStreet:Map::OSM
# OSM maps on FixMyStreet.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::OSM;

use strict;
use Math::Trig;
use mySociety::Gaze;
use Utils;

use constant ZOOM_LEVELS    => 6;
use constant MIN_ZOOM_LEVEL => 13;

sub map_type {
    return 'OpenLayers.Layer.OSM.Mapnik';
}

sub map_template {
    return 'osm';
}

sub map_tiles {
    my ( $self, %params ) = @_;
    my ( $x, $y, $z ) = ( $params{x_tile}, $params{y_tile}, $params{zoom_act} );
    my $tile_url = $self->base_tile_url();
    return [
        "https://a.$tile_url/$z/" . ($x - 1) . "/" . ($y - 1) . ".png",
        "https://b.$tile_url/$z/$x/" . ($y - 1) . ".png",
        "https://c.$tile_url/$z/" . ($x - 1) . "/$y.png",
        "https://a.$tile_url/$z/$x/$y.png",
    ];
}

sub base_tile_url {
    return 'tile.openstreetmap.org';
}

sub copyright {
    _('&copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors');
}

# display_map C PARAMS
# PARAMS include:
# latitude, longitude for the centre point of the map
# CLICKABLE is set if the map is clickable
# PINS is array of pins to show, location and colour
sub display_map {
    my ($self, $c, %params) = @_;

    my $numZoomLevels = ZOOM_LEVELS;
    my $zoomOffset = MIN_ZOOM_LEVEL;
    if ($params{any_zoom}) {
        $numZoomLevels = 19;
        $zoomOffset = 0;
    }

    # Adjust zoom level dependent upon population density
    my $dist = $c->stash->{distance}
        || mySociety::Gaze::get_radius_containing_population( $params{latitude}, $params{longitude}, 200_000 );
    my $default_zoom = $c->cobrand->default_map_zoom() ? $c->cobrand->default_map_zoom() : $numZoomLevels - 4;
    $default_zoom = $numZoomLevels - 3 if $dist < 10;

    # Map centre may be overridden in the query string
    $params{latitude} = Utils::truncate_coordinate($c->get_param('lat') + 0)
        if defined $c->get_param('lat');
    $params{longitude} = Utils::truncate_coordinate($c->get_param('lon') + 0)
        if defined $c->get_param('lon');

    my $zoom = defined $c->get_param('zoom') ? $c->get_param('zoom') + 0 : $default_zoom;
    $zoom = $numZoomLevels - 1 if $zoom >= $numZoomLevels;
    $zoom = 0 if $zoom < 0;
    $params{zoom_act} = $zoomOffset + $zoom;
    ($params{x_tile}, $params{y_tile}) = latlon_to_tile_with_adjust($params{latitude}, $params{longitude}, $params{zoom_act});

    foreach my $pin (@{$params{pins}}) {
        ($pin->{px}, $pin->{py}) = latlon_to_px($pin->{latitude}, $pin->{longitude}, $params{x_tile}, $params{y_tile}, $params{zoom_act});
    }

    $c->stash->{map} = {
        %params,
        type => $self->map_template(),
        map_type => $self->map_type(),
        tiles => $self->map_tiles( %params ),
        copyright => $self->copyright(),
        zoom => $zoom,
        zoomOffset => $zoomOffset,
        numZoomLevels => $numZoomLevels,
        compass => compass( $params{x_tile}, $params{y_tile}, $params{zoom_act} ),
    };
}

sub compass {
    my ( $x, $y, $z ) = @_;
    return {
        north => [ map { Utils::truncate_coordinate($_) } tile_to_latlon( $x, $y-1, $z ) ],
        south => [ map { Utils::truncate_coordinate($_) } tile_to_latlon( $x, $y+1, $z ) ],
        west  => [ map { Utils::truncate_coordinate($_) } tile_to_latlon( $x-1, $y, $z ) ],
        east  => [ map { Utils::truncate_coordinate($_) } tile_to_latlon( $x+1, $y, $z ) ],
        here  => [ map { Utils::truncate_coordinate($_) } tile_to_latlon( $x, $y, $z ) ],
    };
}

# Given a lat/lon, convert it to OSM tile co-ordinates (precise).
sub latlon_to_tile($$$) {
    my ($lat, $lon, $zoom) = @_;
    my $x_tile = ($lon + 180) / 360 * 2**$zoom;
    my $y_tile = (1 - log(tan(deg2rad($lat)) + sec(deg2rad($lat))) / pi) / 2 * 2**$zoom;
    return ( $x_tile, $y_tile );
}

# Given a lat/lon, convert it to OSM tile co-ordinates (nearest actual tile,
# adjusted so the point will be near the centre of a 2x2 tiled map).
sub latlon_to_tile_with_adjust($$$) {
    my ($lat, $lon, $zoom) = @_;
    my ($x_tile, $y_tile) = latlon_to_tile($lat, $lon, $zoom);

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
    my ($x, $y, $zoom) = @_;
    my $n = 2 ** $zoom;
    my $lon = $x / $n * 360 - 180;
    my $lat = rad2deg(atan(sinh(pi * (1 - 2 * $y / $n))));
    return ( $lat, $lon );
}

# Given a lat/lon, convert it to pixel co-ordinates from the top left of the map
sub latlon_to_px($$$$$) {
    my ($lat, $lon, $x_tile, $y_tile, $zoom) = @_;
    my ($pin_x_tile, $pin_y_tile) = latlon_to_tile($lat, $lon, $zoom);
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
# XXX Note use of MIN_ZOOM_LEVEL here.
sub click_to_wgs84 {
    my ($self, $c, $pin_tile_x, $pin_x, $pin_tile_y, $pin_y) = @_;
    my $tile_x = click_to_tile($pin_tile_x, $pin_x);
    my $tile_y = click_to_tile($pin_tile_y, $pin_y);
    my $zoom = MIN_ZOOM_LEVEL + (defined $c->get_param('zoom') ? $c->get_param('zoom') : 3);
    my ($lat, $lon) = tile_to_latlon($tile_x, $tile_y, $zoom);
    return ( $lat, $lon );
}

1;
