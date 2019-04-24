# FixMyStreet:Map::WMTSBase
# Makes it easier for cobrands to use their own WMTS base map.
# This cannot be used directly; you must subclass it and implement several
# methods. See, e.g. FixMyStreet::Map::Zurich or FixMyStreet::Map::Bristol.

package FixMyStreet::Map::WMTSBase;

use strict;
use Math::Trig;
use Utils;
use JSON::MaybeXS;

sub scales {
    my $self = shift;
    my @scales = (
        # A list of scales corresponding to zoom levels, e.g.
        # '192000',
        # '96000',
        # '48000',
        # etc...
    );
    return @scales;
}

# The copyright string to display in the corner of the map.
sub copyright {
    return '';
}

# A hash of parameters that control the zoom options for the map
sub zoom_parameters {
    my $self = shift;
    my $params = {
        zoom_levels    => scalar $self->scales,
        default_zoom   => 0,
        min_zoom_level => 0,
        id_offset      => 0,
    };
    return $params;
}

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

# This is used to determine which template to render the map with
sub map_template { 'fms' }

# Reproject a WGS84 lat/lon into an x/y coordinate in this map's CRS.
# Subclasses will want to override this.
sub reproject_from_latlon($$$) {
    my ($self, $lat, $lon) = @_;
    return (0.0, 0.0);
}

# Reproject a x/y coordinate from this map's CRS into WGS84 lat/lon
# Subclasses will want to override this.
sub reproject_to_latlon($$$) {
    my ($self, $x, $y) = @_;
    return (0.0, 0.0);
}


sub map_tiles {
    my ($self, %params) = @_;
    my ($left_col, $top_row, $z) = @params{'x_left_tile', 'y_top_tile', 'matrix_id'};
    my $tile_url = $self->tile_base_url;
    my $tile_suffix = $self->tile_parameters->{suffix};
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
                    my $src = sprintf '%s/%d/%d/%d%s',
                        $tile_url, $z, $row, $col, $tile_suffix;
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

    my $zoom_params = $self->zoom_parameters;

    $params{zoom} = do {
        my $zoom = defined $c->get_param('zoom')
            ? $c->get_param('zoom') + 0
            : $c->stash->{page} eq 'report'
                ? $zoom_params->{default_zoom}+1
                : $zoom_params->{default_zoom};
        $zoom = $zoom_params->{zoom_levels} - 1
            if $zoom >= $zoom_params->{zoom_levels};
        $zoom = 0 if $zoom < 0;
        $zoom;
    };

    $c->stash->{map} = $self->get_map_hash( %params );

    if ($params{print_report}) {
        $params{zoom}++ unless $params{zoom} >= $zoom_params->{zoom_levels};
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
        = $self->latlon_to_tile_with_adjust(
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
                = $self->latlon_to_px($pin->{latitude}, $pin->{longitude},
                            @params{'x_left_tile', 'y_top_tile', 'zoom'});
            $pin;
        } @{ $params{pins} }
    ];

    my @scales = $self->scales;
    return {
        %params,
        type => $self->map_template,
        map_type => 'OpenLayers.Layer.WMTS',
        tiles => $self->map_tiles( %params ),
        copyright => $self->copyright(),
        zoom => $params{zoom},
        zoomOffset => $self->zoom_parameters->{min_zoom_level},
        numZoomLevels => $self->zoom_parameters->{zoom_levels},
        tile_size => $self->tile_parameters->{size},
        tile_dpi => $self->tile_parameters->{dpi},
        tile_urls => encode_json( $self->tile_parameters->{urls} ),
        tile_suffix => $self->tile_parameters->{suffix},
        layer_names => encode_json( $self->tile_parameters->{layer_names} ),
        layer_style => $self->tile_parameters->{layer_style},
        matrix_set => $self->tile_parameters->{matrix_set},
        map_projection => $self->tile_parameters->{projection},
        origin_x => force_float_format($self->tile_parameters->{origin_x}),
        origin_y => force_float_format($self->tile_parameters->{origin_y}),
        scales => encode_json( \@scales ),
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
