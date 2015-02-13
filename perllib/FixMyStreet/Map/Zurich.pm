# FixMyStreet:Map::Zurich
# Zurich have their own tileserver.
#
# Copyright (c) 2012 UK Citizens Online Democracy. All rights reserved.
# Email: steve@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::Zurich;

use strict;
use Geo::Coordinates::CH1903;
use Math::Trig;
use Utils;

use constant ZOOM_LEVELS    => 8;
use constant DEFAULT_ZOOM   => 5;
use constant MIN_ZOOM_LEVEL => 0;
use constant ID_OFFSET      => 2;

sub map_tiles {
    my ( $self, %params ) = @_;
    my ( $col, $row, $z ) = ( $params{x_tile}, $params{y_tile}, $params{matrix_id} );
    my $tile_url = $self->base_tile_url();
    return [
        "$tile_url/$z/" . ($row - 1) . "/" . ($col - 1) . ".jpg",
        "$tile_url/$z/" . ($row - 1) . "/$col.jpg",
        "$tile_url/$z/$row/" . ($col - 1) . ".jpg",
        "$tile_url/$z/$row/$col.jpg",
    ];
}

sub base_tile_url {
    return '/maps/Hybrid/1.0.0/Hybrid/default/nativeTileMatrixSet';
}

sub copyright {
    return '&copy; Stadt Z&uuml;rich';
}

# display_map C PARAMS
# PARAMS include:
# latitude, longitude for the centre point of the map
# CLICKABLE is set if the map is clickable
# PINS is array of pins to show, location and colour
sub display_map {
    my ($self, $c, %params) = @_;

    # Map centre may be overridden in the query string
    $params{latitude} = Utils::truncate_coordinate($c->req->params->{lat} + 0)
        if defined $c->req->params->{lat};
    $params{longitude} = Utils::truncate_coordinate($c->req->params->{lon} + 0)
        if defined $c->req->params->{lon};

    my $zoom = defined $c->req->params->{zoom}
        ? $c->req->params->{zoom} + 0
        : $c->stash->{page} eq 'report'
            ? DEFAULT_ZOOM+1
            : DEFAULT_ZOOM;
    $zoom = ZOOM_LEVELS - 1 if $zoom >= ZOOM_LEVELS;
    $zoom = 0 if $zoom < 0;

    ($params{x_tile}, $params{y_tile}, $params{matrix_id}) = latlon_to_tile_with_adjust($params{latitude}, $params{longitude}, $zoom);

    foreach my $pin (@{$params{pins}}) {
        ($pin->{px}, $pin->{py}) = latlon_to_px($pin->{latitude}, $pin->{longitude}, $params{x_tile}, $params{y_tile}, $zoom);
    }

    $c->stash->{map} = {
        %params,
        type => 'zurich',
        map_type => 'OpenLayers.Layer.WMTS',
        tiles => $self->map_tiles( %params ),
        copyright => $self->copyright(),
        zoom => $zoom,
        zoomOffset => MIN_ZOOM_LEVEL,
        numZoomLevels => ZOOM_LEVELS,
    };
}

# Given a lat/lon, convert it to Zurch tile co-ordinates (precise).
sub latlon_to_tile($$$) {
    my ($lat, $lon, $zoom) = @_;

    my ($x, $y) = Geo::Coordinates::CH1903::from_latlon($lat, $lon);

    my $matrix_id = $zoom + ID_OFFSET;
    my @scales = ( '250000', '125000', '64000', '32000', '16000', '8000', '4000', '2000', '1000', '500' );
    my $tileOrigin = { lat => 30814423, lon => -29386322 };
    my $tileSize = 256;
    my $res = $scales[$matrix_id] / (39.3701 * 96); # OpenLayers.INCHES_PER_UNIT[units] * OpenLayers.DOTS_PER_INCH

    my $fx = ( $x - $tileOrigin->{lon} ) / ($res * $tileSize);
    my $fy = ( $tileOrigin->{lat} - $y ) / ($res * $tileSize);

    return ( $fx, $fy, $matrix_id );
}

# Given a lat/lon, convert it to OSM tile co-ordinates (nearest actual tile,
# adjusted so the point will be near the centre of a 2x2 tiled map).
sub latlon_to_tile_with_adjust($$$) {
    my ($lat, $lon, $zoom) = @_;
    my ($x_tile, $y_tile, $matrix_id) = latlon_to_tile($lat, $lon, $zoom);

    # Try and have point near centre of map
    if ($x_tile - int($x_tile) > 0.5) {
        $x_tile += 1;
    }
    if ($y_tile - int($y_tile) > 0.5) {
        $y_tile += 1;
    }

    return ( int($x_tile), int($y_tile), $matrix_id );
}

sub tile_to_latlon {
    my ($fx, $fy, $zoom) = @_;

    my $matrix_id = $zoom + ID_OFFSET;
    my @scales = ( '250000', '125000', '64000', '32000', '16000', '8000', '4000', '2000', '1000', '500' );
    my $tileOrigin = { lat => 30814423, lon => -29386322 };
    my $tileSize = 256;
    my $res = $scales[$matrix_id] / (39.3701 * 96); # OpenLayers.INCHES_PER_UNIT[units] * OpenLayers.DOTS_PER_INCH

    my $x = $fx * $res * $tileSize + $tileOrigin->{lon};
    my $y = $tileOrigin->{lat} - $fy * $res * $tileSize;

    my ($lat, $lon) = Geo::Coordinates::CH1903::to_latlon($x, $y);

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
sub click_to_wgs84 {
    my ($self, $c, $pin_tile_x, $pin_x, $pin_tile_y, $pin_y) = @_;
    my $tile_x = click_to_tile($pin_tile_x, $pin_x);
    my $tile_y = click_to_tile($pin_tile_y, $pin_y);
    my $zoom = (defined $c->req->params->{zoom} ? $c->req->params->{zoom} : DEFAULT_ZOOM);
    my ($lat, $lon) = tile_to_latlon($tile_x, $tile_y, $zoom);
    return ( $lat, $lon );
}

1;
