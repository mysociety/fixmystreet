#!/usr/bin/perl
#
# FixMyStreet:Map::OSM
# OSM maps on FixMyStreet.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::OSM;

use strict;
use Math::Trig;
use Utils;

sub header_js {
    return '
<script type="text/javascript" src="/jslib/OpenLayers-2.10/OpenLayers.js"></script>
<script type="text/javascript" src="/js/map-OpenLayers.js"></script>
<script type="text/javascript" src="/js/map-OpenStreetMap.js"></script>
';
}

sub map_type {
    return 'OpenLayers.Layer.OSM.Mapnik';
}

sub base_tile_url {
    return 'tile.openstreetmap.org';
}

sub copyright {
    return _('Map &copy; <a id="osm_link" href="http://www.openstreetmap.org/">OpenStreetMap</a> and contributors, <a href="http://creativecommons.org/licenses/by-sa/2.0/">CC-BY-SA</a>');
}

# display_map C PARAMS
# PARAMS include:
# latitude, longitude for the centre point of the map
# TYPE is 1 if the map is clickable, 0 otherwise.
# PINS is array of pins to show, location and colour
sub display_map {
    my ($self, $c, %params) = @_;

    # Map centre may be overridden in the query string
    $params{latitude} = Utils::truncate_coordinate($c->req->params->{lat} + 0)
        if defined $c->req->params->{lat};
    $params{longitude} = Utils::truncate_coordinate($c->req->params->{lon} + 0)
        if defined $c->req->params->{lon};

    my $zoom = defined $c->req->params->{zoom} ? $c->req->params->{zoom} + 0 : 2;
    $zoom = 3 if $zoom > 3;
    $zoom = 0 if $zoom < 0;
    my $zoom_act = 14 + $zoom;
    my ($x_tile, $y_tile) = latlon_to_tile_with_adjust($params{latitude}, $params{longitude}, $zoom_act);

    my @pins;
    foreach my $pin (@{$params{pins}}) {
        my ($px, $py) = latlon_to_px($pin->[0], $pin->[1], $x_tile, $y_tile, $zoom_act);
        push @pins, {
            lat => $pin->[0],
            lon => $pin->[1],
            px => $px,
            py => $py,
            col => $pin->[2],
            id => $pin->[3],
            title => $pin->[4],
        };
    }

    my $compass = {
        north => [ map { Utils::truncate_coordinate($_) } tile_to_latlon( $x_tile, $y_tile-1, $zoom_act ) ],
        south => [ map { Utils::truncate_coordinate($_) } tile_to_latlon( $x_tile, $y_tile+1, $zoom_act ) ],
        west  => [ map { Utils::truncate_coordinate($_) } tile_to_latlon( $x_tile-1, $y_tile, $zoom_act ) ],
        east  => [ map { Utils::truncate_coordinate($_) } tile_to_latlon( $x_tile+1, $y_tile, $zoom_act ) ],
        here  => [ map { Utils::truncate_coordinate($_) } tile_to_latlon( $x_tile, $y_tile, $zoom_act ) ],
    };
    $c->stash->{map} = {
        type => 'osm',
        clickable => $params{type},
        latitude => $params{latitude},
        longitude => $params{longitude},
        map_type => $self->map_type(),
        tile_url => $self->base_tile_url(),
        copyright => $self->copyright(),
        x_tile => $x_tile,
        y_tile => $y_tile,
        zoom => $zoom,
        zoom_act => $zoom_act,
        pins => \@pins,
        compass => $compass,
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
sub click_to_wgs84 {
    my ($self, $c, $pin_tile_x, $pin_x, $pin_tile_y, $pin_y) = @_;
    my $tile_x = click_to_tile($pin_tile_x, $pin_x);
    my $tile_y = click_to_tile($pin_tile_y, $pin_y);
    my $zoom = 14 + (defined $c->req->params->{zoom} ? $c->req->params->{zoom} : 2);
    my ($lat, $lon) = tile_to_latlon($tile_x, $tile_y, $zoom);
    return ( $lat, $lon );
}

1;
