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
use mySociety::Gaze;
use Utils;

use constant ZOOM_LEVELS    => 5;
use constant MIN_ZOOM_LEVEL => 13;

sub map_type {
    return 'OpenLayers.Layer.OSM.Mapnik';
}

sub map_template {
    return 'osm';
}

sub map_tiles {
    my ($self, $x, $y, $z) = @_;
    my $tile_url = $self->base_tile_url();
    return [
        "http://a.$tile_url/$z/" . ($x - 1) . "/" . ($y - 1) . ".png",
        "http://b.$tile_url/$z/$x/" . ($y - 1) . ".png",
        "http://c.$tile_url/$z/" . ($x - 1) . "/$y.png",
        "http://$tile_url/$z/$x/$y.png",
    ];
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
# CLICKABLE is set if the map is clickable
# PINS is array of pins to show, location and colour
sub display_map {
    my ($self, $c, %params) = @_;

    my $numZoomLevels = ZOOM_LEVELS;
    my $zoomOffset = MIN_ZOOM_LEVEL;
    if ($params{any_zoom}) {
        $numZoomLevels = 18;
        $zoomOffset = 0;
    }

    # Adjust zoom level dependent upon population density
    my $dist = mySociety::Gaze::get_radius_containing_population( $params{latitude}, $params{longitude}, 200_000 );
    my $default_zoom = $numZoomLevels - 3;
    $default_zoom = $numZoomLevels - 2 if $dist < 10;

    # Map centre may be overridden in the query string
    $params{latitude} = Utils::truncate_coordinate($c->req->params->{lat} + 0)
        if defined $c->req->params->{lat};
    $params{longitude} = Utils::truncate_coordinate($c->req->params->{lon} + 0)
        if defined $c->req->params->{lon};

    my $zoom = defined $c->req->params->{zoom} ? $c->req->params->{zoom} + 0 : $default_zoom;
    $zoom = $numZoomLevels - 1 if $zoom >= $numZoomLevels;
    $zoom = 0 if $zoom < 0;
    my $zoom_act = $zoomOffset + $zoom;
    my ($x_tile, $y_tile) = latlon_to_tile_with_adjust($params{latitude}, $params{longitude}, $zoom_act);

    foreach my $pin (@{$params{pins}}) {
        ($pin->{px}, $pin->{py}) = latlon_to_px($pin->{latitude}, $pin->{longitude}, $x_tile, $y_tile, $zoom_act);
    }

    $c->stash->{map} = {
        %params,
        type => $self->map_template(),
        map_type => $self->map_type(),
        tiles => $self->map_tiles( $x_tile, $y_tile, $zoom_act ),
        copyright => $self->copyright(),
        x_tile => $x_tile,
        y_tile => $y_tile,
        zoom => $zoom,
        zoom_act => $zoom_act,
        zoomOffset => $zoomOffset,
        numZoomLevels => $numZoomLevels,
        compass => compass( $x_tile, $y_tile, $zoom_act ),
    };
}

sub map_pins {
    my ($self, $c, $interval) = @_;

    my $bbox = $c->req->param('bbox');
    my ( $min_lon, $min_lat, $max_lon, $max_lat ) = split /,/, $bbox;

    my ( $around_map, $around_map_list, $nearby, $dist ) =
      FixMyStreet::Map::map_features_bounds( $c, $min_lon, $min_lat, $max_lon, $max_lat, $interval );

    # create a list of all the pins
    my @pins = map {
        # Here we might have a DB::Problem or a DB::Nearby, we always want the problem.
        my $p = (ref $_ eq 'FixMyStreet::App::Model::DB::Nearby') ? $_->problem : $_;
        #{
        #    latitude  => $p->latitude,
        #    longitude => $p->longitude,
        #    colour    => $p->state eq 'fixed' ? 'green' : 'red',
        #    id        => $p->id,
        #    title     => $p->title,
        #}
        [ $p->latitude, $p->longitude, $p->state eq 'fixed' ? 'green' : 'red', $p->id, $p->title ]
    } @$around_map, @$nearby;

    return (\@pins, $around_map_list, $nearby, $dist);
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
    my $zoom = MIN_ZOOM_LEVEL + (defined $c->req->params->{zoom} ? $c->req->params->{zoom} : 3);
    my ($lat, $lon) = tile_to_latlon($tile_x, $tile_y, $zoom);
    return ( $lat, $lon );
}

1;
