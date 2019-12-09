# FixMyStreet:Map::WMTSBase
# Makes it easier for cobrands to use their own WMTS base map.
# This cannot be used directly; you must subclass it and implement several
# methods. See, e.g. FixMyStreet::Map::Zurich or FixMyStreet::Map::Bristol.

package FixMyStreet::Map::WMTSBase;
use parent FixMyStreet::Map::WMXBase;

use strict;

# A hash of parameters used in calculations for map tiles
sub tile_parameters {
    my $params = {
        urls         => [ '' ], # URL of the map tiles, up to the /{z}/{x}/{y} part
        layer_names  => [ '' ],
        wmts_version => '1.0.0',
        layer_style  => '',
        matrix_set   => '',
        suffix       => '', # appended to tile URLs
        size         => 256, # pixels
        dpi          => 96,
        inches_per_unit => 0, # See OpenLayers.INCHES_PER_UNIT for some options.
        origin_x     => 0,
        origin_y     => 0,
        projection   => 'EPSG:3857', # Passed through to OpenLayers.Projection
    };
    return $params;
}

sub _get_tile_params {
    my ($self, $params, $left_col, $top_row, $z, $tile_url) = @_;

    return ($tile_url, $z, $self->tile_parameters->{suffix});
}

sub _get_tile_src {
    my ($self, $tile_url, $z, $suffix, $col, $row) = @_;

    return sprintf( '%s/%d/%d/%d%s',
        $tile_url, $z, $row, $col, $suffix);
}

sub _get_tile_id {
    my ($self, $tile_url, $x, $suffix, $col, $row) = @_;

    return sprintf( '%d.%d', $col, $row);
}

sub _get_row {
    my ($self, $top_row, $row_offset, $size) = @_;
    return $top_row + $row_offset;
}

sub _get_col {
    my ($self, $left_col, $col_offset, $size) = @_;
    return $left_col + $col_offset;
}

sub map_type { 'OpenLayers.Layer.WMTS' }

sub _map_hash_extras {
    my $self = shift;

    return {
        layer_style => $self->tile_parameters->{layer_style},
        matrix_set => $self->tile_parameters->{matrix_set},
        origin_x => force_float_format($self->tile_parameters->{origin_x}),
        origin_y => force_float_format($self->tile_parameters->{origin_y}),
        tile_suffix => $self->tile_parameters->{suffix},
    };
}

sub tile_base_url {
    my $self = shift;
    my $params = $self->tile_parameters;
    return sprintf '%s/%s/%s/%s/%s',
        $params->{urls}[0], $params->{wmts_version}, $params->{layer_names}[0],
        $params->{layer_style}, $params->{matrix_set};
}

# Given a lat/lon, convert it to tile co-ordinates (precise).
sub latlon_to_tile($$$$) {
    my ($self, $lat, $lon, $zoom) = @_;

    my ($x, $y) = $self->reproject_from_latlon($lat, $lon);

    my $tile_params = $self->tile_parameters;

    my $matrix_id = $zoom + $self->zoom_parameters->{id_offset};
    my @scales = $self->scales;
    my $tileOrigin = {
        lon => $tile_params->{origin_x},
        lat => $tile_params->{origin_y}
    };
    my $res = $scales[$zoom] /
        ($tile_params->{inches_per_unit} * $tile_params->{dpi});
        # OpenLayers.INCHES_PER_UNIT[units] * OpenLayers.DOTS_PER_INCH

    my $fx = ( $x - $tileOrigin->{lon} ) / ($res * $tile_params->{size});
    my $fy = ( $tileOrigin->{lat} - $y ) / ($res * $tile_params->{size});

    return ( $fx, $fy, $matrix_id );
}

# Given a lat/lon, convert it to OSM tile co-ordinates (nearest actual tile,
# adjusted so the point will be near the centre of a 2x2 tiled map).
#
# Takes parameter for rows/cols.  For even sizes (2x2, 4x4 etc.) will
# do adjustment, but simply returns actual for odd sizes.
#
sub latlon_to_tile_with_adjust {
    my ($self, $lat, $lon, $zoom, $rows, $cols) = @_;
    my ($x_tile, $y_tile, $matrix_id)
        = my @ret
        = $self->latlon_to_tile($lat, $lon, $zoom);

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
    my ($self, $fx, $fy, $zoom) = @_;

    my $tile_params = $self->tile_parameters;
    my @scales = $self->scales;
    my $tileOrigin = {
        lon => $tile_params->{origin_x},
        lat => $tile_params->{origin_y}
    };
    my $res = $scales[$zoom] /
        ($tile_params->{inches_per_unit} * $tile_params->{dpi});
        # OpenLayers.INCHES_PER_UNIT[units] * OpenLayers.DOTS_PER_INCH

    my $x = $fx * $res * $tile_params->{size} + $tileOrigin->{lon};
    my $y = $tileOrigin->{lat} - $fy * $res * $tile_params->{size};

    my ($lat, $lon) = $self->reproject_to_latlon($x, $y);

    return ( $lat, $lon );
}

# Given a lat/lon, convert it to pixel co-ordinates from the top left of the map
sub latlon_to_px($$$$$$) {
    my ($self, $lat, $lon, $x_tile, $y_tile, $zoom) = @_;
    my ($pin_x_tile, $pin_y_tile) = $self->latlon_to_tile($lat, $lon, $zoom);
    my $pin_x = $self->tile_to_px($pin_x_tile, $x_tile);
    my $pin_y = $self->tile_to_px($pin_y_tile, $y_tile);
    return ($pin_x, $pin_y);
}

# Convert tile co-ordinates to pixel co-ordinates from top left of map
# C is centre tile reference of displayed map
sub tile_to_px {
    my ($self, $p, $c) = @_;
    $p = $self->tile_parameters->{size} * ($p - $c);
    $p = int($p + .5 * ($p <=> 0));
    return $p;
}

sub click_to_tile {
    my ($self, $pin_tile, $pin) = @_;
    my $tile_size = $self->tile_parameters->{size};
    $pin -= $tile_size while $pin > $tile_size;
    $pin += $tile_size while $pin < 0;
    return $pin_tile + $pin / $tile_size;
}

# Given some click co-ords (the tile they were on, and where in the
# tile they were), convert to WGS84 and return.
sub click_to_wgs84 {
    my ($self, $c, $pin_tile_x, $pin_x, $pin_tile_y, $pin_y) = @_;
    my $tile_x = $self->click_to_tile($pin_tile_x, $pin_x);
    my $tile_y = $self->click_to_tile($pin_tile_y, $pin_y);
    my $zoom = (defined $c->get_param('zoom') ? $c->get_param('zoom') : $self->zoom_parameters->{default_zoom});
    my ($lat, $lon) = $self->tile_to_latlon($tile_x, $tile_y, $zoom);
    return ( $lat, $lon );
}

sub force_float_format {
  my $in = shift;
  return mySociety::Locale::in_gb_locale {
      sprintf( '%f', $in );
  };
}

1;
