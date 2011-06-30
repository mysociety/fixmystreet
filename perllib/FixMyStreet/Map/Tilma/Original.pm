#!/usr/bin/perl
#
# FixMyStreet:Map
# Adding the ability to have different maps on FixMyStreet.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::Tilma::Original;

use strict;
use LWP::Simple;

use mySociety::GeoUtil;
use mySociety::Locale;
use mySociety::Web qw(ent NewURL);
use Utils;
use RABX;

sub TILE_WIDTH()   { return $FixMyStreet::Map::map_class->tile_width;   }
sub SCALE_FACTOR() { return $FixMyStreet::Map::map_class->scale_factor; }
sub TILE_TYPE()    { return $FixMyStreet::Map::map_class->tile_type;    }

sub _ll_to_en {
    my ($lat, $lon) = @_;
    return Utils::convert_latlon_to_en( $lat, $lon );
}

# display_map C PARAMS
# PARAMS include:
# latitude, longitude for the centre point of the map
# CLICKABLE is set if the map is clickable
# PINS is array of pins to show, location and colour
sub display_map {
    my ($self, $c, %params) = @_;
    my $mid_point = TILE_WIDTH; # Map is 2 TILE_WIDTHs in size, square.
    if (my $mp = $c->cobrand->tilma_mid_point) {
        $mid_point = $mp;
    }

    # convert map center point to easting, northing
    ( $params{easting}, $params{northing} ) =
      _ll_to_en( $params{latitude}, $params{longitude} );

    # X/Y tile co-ords may be overridden in the query string
    my @vars = qw(x y);
    my %input = map { $_ => $c->req->params->{$_} || '' } @vars;
    ($input{x}) = $input{x} =~ /^(\d+)/; $input{x} ||= 0;
    ($input{y}) = $input{y} =~ /^(\d+)/; $input{y} ||= 0;

    my ($x, $y, $px, $py) = os_to_px_with_adjust($c, $params{easting}, $params{northing}, $input{x}, $input{y});

    foreach my $pin (@{$params{pins}}) {
        my ( $e, $n ) = _ll_to_en( $pin->{latitude}, $pin->{longitude} );
        $pin->{px} = os_to_px($e, $x);
        $pin->{py} = os_to_px($n, $y, 1);
    }

    $px = defined($px) ? $mid_point - $px : 0;
    $py = defined($py) ? $mid_point - $py : 0;
    $x = int($x)<=0 ? 0 : $x;
    $y = int($y)<=0 ? 0 : $y;
    my $url = 'http://tilma.mysociety.org/tileserver/' . TILE_TYPE . '/';
    my $tiles_url = $url . ($x-1) . '-' . $x . ',' . ($y-1) . '-' . $y . '/RABX';
    my $tiles = LWP::Simple::get($tiles_url);
    my $tileids = RABX::unserialise($tiles);
    $c->stash->{map} = {
        %params,
        type => 'tilma/original',
        tiles => $tiles,
        url => $url,
        tileids => $tileids,
        x => $x,
        y => $y,
        px => $px,
        py => $py,
        tile_type => TILE_TYPE,
        tilewidth => TILE_WIDTH,
        watermark => $self->watermark(),
        copyright => $self->copyright(),
    };
}

sub display_pin {
    my ($c, $px, $py, $col, $id, $title, $num) = @_;
    $num = '' if !$num || $num > 9;
    my $host = $c->cobrand->base_url_with_lang;
    my %cols = (red=>'R', green=>'G', blue=>'B', purple=>'P');
    my $out = '<img class="pin" src="' . $host . '/i/pin' . $cols{$col}
        . $num . '.gif" alt="' . _('Problem') . '" style="top:' . ($py-59)
        . 'px; left:' . ($px) . 'px; position: absolute;">';
    return $out unless $id;
    my $url = $c->uri_for( '/report/' . $id );
    $out = '<a title="' . ent($title) . '" href="' . $url . '">' . $out . '</a>';
    return $out;
}

sub map_pins {
    my ($self, $c, $interval) = @_;

    # Our current X/Y middle of visible map
    my $x = ( $c->req->param('x') || 0 ) + 0;
    my $y = ( $c->req->param('y') || 0 ) + 0;

    # Where we started as that's the (0,0) we have to work to
    my $sx = ( $c->req->param('sx') || 0 ) + 0;
    my $sy = ( $c->req->param('sy') || 0 ) + 0;

    my $e = tile_to_os($x);
    my $n = tile_to_os($y);

    my ( $lat, $lon ) = Utils::convert_en_to_latlon( $e, $n );
    my ( $around_map, $around_map_list, $nearby, $dist ) =
      FixMyStreet::Map::map_features( $c, $lat, $lon, $interval );

    my $pins = '';
    foreach (@$around_map) {
        my ( $easting, $northing ) =
          _ll_to_en( $_->latitude, $_->longitude );
        my $px = os_to_px($easting, $sx);
        my $py = os_to_px($northing, $sy, 1);
        my $col = $_->state eq 'fixed' ? 'green' : 'red';
        $pins .= display_pin($c, $px, $py, $col, $_->id, $_->title);
    }

    foreach (@$nearby) {
        my $p = $_->problem;
        my ( $easting, $northing ) =
          _ll_to_en( $p->latitude, $p->longitude );
        my $px = os_to_px($easting, $sx);
        my $py = os_to_px($northing, $sy, 1);
        my $col = $p->state eq 'fixed' ? 'green' : 'red';
        $pins .= display_pin($c, $px, $py, $col, $p->id, $p->title);
    }

    return ($pins, $around_map_list, $nearby, $dist);
}

# P is easting or northing
# C is centre tile reference of displayed map
sub os_to_px {
    my ($p, $c, $invert) = @_;
    return tile_to_px(os_to_tile($p), $c, $invert);
}

# Convert tile co-ordinates to pixel co-ordinates from top left of map
# C is centre tile reference of displayed map
sub tile_to_px {
    my ($p, $c, $invert) = @_;
    $p = TILE_WIDTH * ($p - $c + 1);
    $p = 2 * TILE_WIDTH - $p if $invert;
    $p = int($p + .5 * ($p <=> 0));
    return $p;
}

# Tile co-ordinates are linear scale of OS E/N
# Will need more generalising when more zooms appear
sub os_to_tile {
    return $_[0] / SCALE_FACTOR;
}

sub tile_to_os {
    return int($_[0] * SCALE_FACTOR + 0.5);
}

=head2 tile_xy_to_wgs84

    ($lat, $lon) = tile_xy_to_wgs84( $x, $y );

Takes the tile x,y and converts to lat, lon.

=cut

sub tile_xy_to_wgs84 {
    my ( $self, $x, $y ) = @_;

    my $easting  = tile_to_os($x);
    my $northing = tile_to_os($y);

    my ( $lat, $lon ) = Utils::convert_en_to_latlon( $easting, $northing );
    return ( $lat, $lon );
}


sub click_to_tile {
    my ($pin_tile, $pin, $invert) = @_;
    $pin -= TILE_WIDTH while $pin > TILE_WIDTH;
    $pin += TILE_WIDTH while $pin < 0;
    $pin = TILE_WIDTH - $pin if $invert; # image submits measured from top down
    return $pin_tile + $pin / TILE_WIDTH;
}

# Given some click co-ords (the tile they were on, and where in the
# tile they were), convert to OSGB36 and return.
sub click_to_os {
    my ($pin_tile_x, $pin_x, $pin_tile_y, $pin_y) = @_;
    my $tile_x = click_to_tile($pin_tile_x, $pin_x);
    my $tile_y = click_to_tile($pin_tile_y, $pin_y, 1);
    my $easting = tile_to_os($tile_x);
    my $northing = tile_to_os($tile_y);
    return ($easting, $northing);
}

# Given some click co-ords (the tile they were on, and where in the
# tile they were), convert to WGS84 and return.
sub click_to_wgs84 {
    my $self = shift;
    my $c = shift;
    my ( $easting, $northing ) = click_to_os(@_);
    my ( $lat, $lon ) = mySociety::GeoUtil::national_grid_to_wgs84( $easting, $northing, 'G' );
    return ( $lat, $lon );
}

# Given (E,N) and potential override (X,Y), return the X/Y tile for the centre
# of the map (either to get the point near the middle, or the override X,Y),
# and the pixel co-ords of the point, relative to that map.
sub os_to_px_with_adjust {
    my ($c, $easting, $northing, $in_x, $in_y) = @_;

    my $x = os_to_tile($easting);
    my $y = os_to_tile($northing);
    my $x_tile = $in_x || int($x);
    my $y_tile = $in_y || int($y);

    # Try and have point near centre of map
    if (!$in_x && $x - $x_tile > 0.5) {
        $x_tile += 1;
    }
    if (!$in_y && $y - $y_tile > 0.5) {
        $y_tile += 1;
    }

    my $px = os_to_px($easting, $x_tile);
    my $py = os_to_px($northing, $y_tile, 1);
    if ($c->cobrand->tilma_mid_point == 189) { # Map is 380px, so might need to adjust
        if (!$in_x && $px > 380) {
            $x_tile++;
            $px = os_to_px($easting, $x_tile);
        }
        if (!$in_y && $py > 380) {
            $y_tile--;
            $py = os_to_px($northing, $y_tile, 1);
        }
    }

    return ($x_tile, $y_tile, $px, $py);
}

1;
