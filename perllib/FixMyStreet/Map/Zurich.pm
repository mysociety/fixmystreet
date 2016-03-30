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

use constant ZOOM_LEVELS    => 9;
use constant DEFAULT_ZOOM   => 5;
use constant MIN_ZOOM_LEVEL => 0;
use constant ID_OFFSET      => 2;
use constant TILE_SIZE      => 512;

sub map_tiles {
    my ($self, %params) = @_;
    my ($left_col, $top_row, $z) = @params{'x_left_tile', 'y_top_tile', 'matrix_id'};
    my $tile_url = $self->base_tile_url();
    my $cols = $params{cols};
    my $rows = $params{rows};

    my @col_offsets = (0.. ($cols-1) );
    my @row_offsets = (0.. ($rows-1) );

    return [
        map {
            my $row_offset = $_;
            [
                map {
                    my $col_offset = $_;
                    my $row = $top_row + $row_offset;
                    my $col = $left_col + $col_offset;
                    my $src = sprintf '%s/%d/%d/%d.jpg',
                        $tile_url, $z, $row, $col;
                    my $dotted_id = sprintf '%d.%d', $col, $row;

                    # return the data structure for the cell
                    +{
                        src => $src,
                        row_offset => $row_offset,
                        col_offset => $col_offset,
                        dotted_id => $dotted_id,
                        alt => "Map tile $dotted_id", # TODO "NW map tile"?
                    }
                }
                @col_offsets
            ]
        }
        @row_offsets
    ];
}

sub base_tile_url {
    # use the new 512px maps as used by Javascript
    return '//www.gis.stadt-zuerich.ch/maps/rest/services/tiled/LuftbildHybrid/MapServer/WMTS/tile/1.0.0/tiled_LuftbildHybrid/default/default028mm';
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
    $params{latitude} = Utils::truncate_coordinate($c->get_param('lat') + 0)
        if defined $c->get_param('lat');
    $params{longitude} = Utils::truncate_coordinate($c->get_param('lon') + 0)
        if defined $c->get_param('lon');

    $params{rows} //= 2; # 2x2 square is default
    $params{cols} //= 2;

    $params{zoom} = do {
        my $zoom = defined $c->get_param('zoom')
            ? $c->get_param('zoom') + 0
            : $c->stash->{page} eq 'report'
                ? DEFAULT_ZOOM+1
                : DEFAULT_ZOOM;
        $zoom = ZOOM_LEVELS - 1 if $zoom >= ZOOM_LEVELS;
        $zoom = 0 if $zoom < 0;
        $zoom;
    };

    $c->stash->{map} = $self->get_map_hash( %params );

    if ($params{print_report}) {
        $params{zoom}++ unless $params{zoom} >= ZOOM_LEVELS;
        $c->stash->{print_report_map}
            = $self->get_map_hash(
                %params,
                img_type => 'img',
                cols => 4, rows => 4,
            );
        # NB: we can passthrough img_type as literal here, as only designed for print

        # NB we can do arbitrary size, including non-squares, however we'd have
        # to modify .square-map style with padding-bottom percentage calculated in
        # an inline style:
        # <zarino> in which case, the only change that'd be required is
        # removing { padding-bottom: 100% } from .square-map__outer, putting
        # the percentage into an inline style on the element itself, and then
        # probably renaming .square-map__* to .fixed-aspect-map__* or something
        # since it's no longer necessarily square
    }
}

sub get_map_hash {
    my ($self, %params) = @_;

    @params{'x_centre_tile', 'y_centre_tile', 'matrix_id'}
        = latlon_to_tile_with_adjust(
            @params{'latitude', 'longitude', 'zoom', 'rows', 'cols'});

    # centre_(row|col) is either in middle, or just to right.
    # e.g. if centre is the number in parens:
    # 1 (2) 3 => 2 - int( 3/2 ) = 1
    # 1 2 (3) 4 => 3 - int( 4/2 ) = 1
    $params{x_left_tile} = $params{x_centre_tile} - int($params{cols} / 2);
    $params{y_top_tile}  = $params{y_centre_tile} - int($params{rows} / 2);

    $params{pins} = [
        map {
            my $pin = { %$_ }; # shallow clone
            ($pin->{px}, $pin->{py})
                = latlon_to_px($pin->{latitude}, $pin->{longitude},
                            @params{'x_left_tile', 'y_top_tile', 'zoom'});
            $pin;
        } @{ $params{pins} }
    ];

    return {
        %params,
        type => 'zurich',
        map_type => 'OpenLayers.Layer.WMTS',
        tiles => $self->map_tiles( %params ),
        copyright => $self->copyright(),
        zoom => $params{zoom},,
        zoomOffset => MIN_ZOOM_LEVEL,
        numZoomLevels => ZOOM_LEVELS,
        tile_size => TILE_SIZE,
    };
}

# Given a lat/lon, convert it to Zurch tile co-ordinates (precise).
sub latlon_to_tile($$$) {
    my ($lat, $lon, $zoom) = @_;

    my ($x, $y) = Geo::Coordinates::CH1903::from_latlon($lat, $lon);

    my $matrix_id = $zoom + ID_OFFSET;
    my @scales = (
        '250000', '125000',
        '64000', '32000',
        '16000', '8000',
        '4000', '2000',
        '1000', '500',
        '250'
    );
    my $tileOrigin = { lat => 30814423, lon => -29386322 };
    my $res = $scales[$matrix_id] / (39.3701 * 96);
        # OpenLayers.INCHES_PER_UNIT[units] * OpenLayers.DOTS_PER_INCH

    my $fx = ( $x - $tileOrigin->{lon} ) / ($res * TILE_SIZE);
    my $fy = ( $tileOrigin->{lat} - $y ) / ($res * TILE_SIZE);

    return ( $fx, $fy, $matrix_id );
}

# Given a lat/lon, convert it to OSM tile co-ordinates (nearest actual tile,
# adjusted so the point will be near the centre of a 2x2 tiled map).
#
# Takes parameter for rows/cols.  For even sizes (2x2, 4x4 etc.) will
# do adjustment, but simply returns actual for odd sizes.
#
sub latlon_to_tile_with_adjust {
    my ($lat, $lon, $zoom, $rows, $cols) = @_;
    my ($x_tile, $y_tile, $matrix_id)
        = my @ret
        = latlon_to_tile($lat, $lon, $zoom);

    # Try and have point near centre of map, passing through if odd
    unless ($cols % 2) {
        if ($x_tile - int($x_tile) > 0.5) {
            $x_tile += 1;
        }
    }
    unless ($rows % 2) {
        if ($y_tile - int($y_tile) > 0.5) {
            $y_tile += 1;
        }
    }

    return ( int($x_tile), int($y_tile), $matrix_id );
}

sub tile_to_latlon {
    my ($fx, $fy, $zoom) = @_;

    my $matrix_id = $zoom + ID_OFFSET;
    my @scales = ( '250000', '125000', '64000', '32000', '16000', '8000', '4000', '2000', '1000', '500', '250' );
    my $tileOrigin = { lat => 30814423, lon => -29386322 };
    my $res = $scales[$matrix_id] / (39.3701 * 96); # OpenLayers.INCHES_PER_UNIT[units] * OpenLayers.DOTS_PER_INCH

    my $x = $fx * $res * TILE_SIZE + $tileOrigin->{lon};
    my $y = $tileOrigin->{lat} - $fy * $res * TILE_SIZE;

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
    $p = TILE_SIZE * ($p - $c);
    $p = int($p + .5 * ($p <=> 0));
    return $p;
}

sub click_to_tile {
    my ($pin_tile, $pin) = @_;
    $pin -= TILE_SIZE while $pin > TILE_SIZE;
    $pin += TILE_SIZE while $pin < 0;
    return $pin_tile + $pin / TILE_SIZE;
}

# Given some click co-ords (the tile they were on, and where in the
# tile they were), convert to WGS84 and return.
sub click_to_wgs84 {
    my ($self, $c, $pin_tile_x, $pin_x, $pin_tile_y, $pin_y) = @_;
    my $tile_x = click_to_tile($pin_tile_x, $pin_x);
    my $tile_y = click_to_tile($pin_tile_y, $pin_y);
    my $zoom = (defined $c->get_param('zoom') ? $c->get_param('zoom') : DEFAULT_ZOOM);
    my ($lat, $lon) = tile_to_latlon($tile_x, $tile_y, $zoom);
    return ( $lat, $lon );
}

1;
