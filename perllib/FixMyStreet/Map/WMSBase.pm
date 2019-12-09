# FixMyStreet:Map::WMSBase
# Makes it easier for cobrands to use their own WMS base map.
# This cannot be used directly; you must subclass it and implement several
# methods. See, e.g. FixMyStreet::Map::Northamptonshire.

package FixMyStreet::Map::WMSBase;
use parent FixMyStreet::Map::WMXBase;

use strict;

# A hash of parameters used in calculations for map tiles
sub tile_parameters {
    my $params = {
        urls         => [ '' ], # URL of the map tiles, up to the /{z}/{x}/{y} part
        layer_names  => [ '' ],
        wms_version => '1.0.0',
        size         => 256, # pixels
        dpi          => 96,
        inches_per_unit => 0, # See OpenLayers.INCHES_PER_UNIT for some options.
        projection   => 'EPSG:3857', # Passed through to OpenLayers.Projection
    };
    return $params;
}

# This is used to determine which template to render the map with
sub map_template { 'wms' }

sub get_res {
    my ($self, $zoom) = @_;

    my @scales = $self->scales;

    my $res = $scales[$zoom] /
        ($self->tile_parameters->{inches_per_unit} * $self->tile_parameters->{dpi});

    return $res;
}

sub _get_tile_size {
    my ($self, $params) = @_;

    my $res = $self->get_res($params->{zoom});
    return $res * $self->tile_parameters->{size};
}

sub _get_tile_params {
    my ($self, $params, $left_col, $top_row, $z, $tile_url, $size) = @_;

    my ($min_x, $min_y, $max_x, $max_y) = ($left_col, $top_row - $size, $left_col + $size, $top_row);

    return ($tile_url, $min_x, $min_y, $max_x, $max_y);
}

sub _get_tile_src {
    my ($self, $tile_url, $min_x, $min_y, $max_x, $max_y, $col, $row) = @_;

    my $src = sprintf( '%s&bbox=%d,%d,%d,%d',
        $tile_url, $min_x + $col, $min_y - $row, $max_x + $col, $max_y - $row);

    return $src;
}

sub _get_tile_id {
    my ($self, $tile_url, $min_x, $min_y, $max_x, $max_y, $col, $row) = @_;

    return sprintf( '%d.%d', ($min_x + $col), ($min_y - $row) );
}

sub _get_row {
    my ($self, $top_row, $row_offset, $size) = @_;
    return $row_offset * $size;
}

sub _get_col {
    my ($self, $left_col, $col_offset, $size) = @_;
    return $col_offset * $size;
}

sub map_type { 'OpenLayers.Layer.WMS' }

sub _map_hash_extras {
    my $self = shift;

    return {
        wms_version => $self->tile_parameters->{wms_version},
        format => $self->tile_parameters->{format},
    };
}

sub tile_base_url {
    my $self = shift;
    my $params = $self->tile_parameters;
    return sprintf '%s?version=%s&format=%s&size=%s&width=%s&height=%s&service=WMS&layers=%s&request=GetMap&srs=%s',
        $params->{urls}[0], $params->{wms_version}, $params->{format}, $params->{size}, $params->{size},
        $params->{size}, $params->{layer_names}[0], $params->{projection};
}

# Given a lat/lon, convert it to tile co-ordinates (nearest actual tile,
# adjusted so the point will be near the centre of a 2x2 tiled map).
sub latlon_to_tile_with_adjust {
    my ($self, $lat, $lon, $zoom, $rows, $cols) = @_;
    my ($x_tile, $y_tile)
        = $self->reproject_from_latlon($lat, $lon, $zoom);

    my $tile_params = $self->tile_parameters;
    my $res = $self->get_res($zoom);

    $x_tile = $x_tile -  ($res * $tile_params->{size});
    $y_tile = $y_tile + ($res * $tile_params->{size});

    return ( int($x_tile), int($y_tile) );
}

sub tile_to_latlon {
    my ($self, $fx, $fy, $zoom) = @_;
    my ($lat, $lon) = $self->reproject_to_latlon($fx, $fy);

    return ($lat, $lon);
}

# Given a lat/lon, convert it to pixel co-ordinates from the top left of the map
sub latlon_to_px($$$$$$) {
    my ($self, $lat, $lon, $x_tile, $y_tile, $zoom) = @_;
    my ($pin_x_tile, $pin_y_tile) = $self->reproject_from_latlon($lat, $lon, $zoom);
    my $res = $self->get_res($zoom);
    my $pin_x = ( $pin_x_tile - $x_tile ) / $res;
    my $pin_y = ( $y_tile - $pin_y_tile ) / $res;
    return ($pin_x, $pin_y);
}

sub click_to_tile {
    my ($self, $pin_tile, $pin, $zoom, $reverse) = @_;
    my $tile_params = $self->tile_parameters;
    my $size = $tile_params->{size};
    my $res = $self->get_res($zoom);

    return $reverse ? $pin_tile + ( ( $size - $pin ) * $res ) : $pin_tile + ( $pin * $res );
}

# Given some click co-ords (the tile they were on, and where in the
# tile they were), convert to WGS84 and return.
sub click_to_wgs84 {
    my ($self, $c, $pin_tile_x, $pin_x, $pin_tile_y, $pin_y) = @_;
    my $zoom = (defined $c->get_param('zoom') ? $c->get_param('zoom') : $self->zoom_parameters->{default_zoom});
    my $tile_x = $self->click_to_tile($pin_tile_x, $pin_x, $zoom);
    my $tile_y = $self->click_to_tile($pin_tile_y, $pin_y, $zoom, 1);
    my ($lat, $lon) = $self->tile_to_latlon($tile_x, $tile_y, $zoom);
    return ( $lat, $lon );
}

1;
