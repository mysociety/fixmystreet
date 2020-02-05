# FixMyStreet:Map::WMXBase
# Common methods for WMS and WMTS maps

package FixMyStreet::Map::WMXBase;

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

sub _get_tile_size {
    return shift->tile_parameters->{size};
}

sub map_tiles {
    my ($self, %params) = @_;
    my ($left_col, $top_row, $z) = @params{'x_left_tile', 'y_top_tile', 'matrix_id'};
    my $tile_url = $self->tile_base_url;
    my $cols = $params{cols};
    my $rows = $params{rows};

    my @col_offsets = (0.. ($cols-1) );
    my @row_offsets = (0.. ($rows-1) );

    my $size = $self->_get_tile_size(\%params);
    my @params = $self->_get_tile_params(\%params, $left_col, $top_row, $z, $tile_url, $size);

    return [
        map {
            my $row_offset = $_;
            [
                map {
                    my $col_offset = $_;
                    my $row = $self->_get_row($top_row, $row_offset, $size);
                    my $col = $self->_get_col($left_col, $col_offset, $size);
                    my $src = $self->_get_tile_src(@params, $col, $row);
                    my $dotted_id = $self->_get_tile_id(@params, $col, $row);

                    # return the data structure for the cell
                    +{
                        src => $src,
                        row_offset => $row_offset,
                        col_offset => $col_offset,
                        dotted_id => $dotted_id,
                        alt => "Map tile $dotted_id",
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
    }
}

sub _map_hash_extras { return {} }

sub get_map_hash {
    my ($self, %params) = @_;

    @params{'x_centre_tile', 'y_centre_tile', 'matrix_id'}
        = $self->latlon_to_tile_with_adjust(
            @params{'latitude', 'longitude', 'zoom', 'rows', 'cols'});

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
        map_type => $self->map_type,
        tiles => $self->map_tiles( %params ),
        copyright => $self->copyright(),
        zoom => $params{zoom},
        zoomOffset => $self->zoom_parameters->{min_zoom_level},
        numZoomLevels => $self->zoom_parameters->{zoom_levels},
        tile_size => $self->tile_parameters->{size},
        tile_dpi => $self->tile_parameters->{dpi},
        tile_urls => encode_json( $self->tile_parameters->{urls} ),
        layer_names => encode_json( $self->tile_parameters->{layer_names} ),
        map_projection => $self->tile_parameters->{projection},
        scales => encode_json( \@scales ),
        compass => $self->compass( $params{x_centre_tile}, $params{y_centre_tile}, $params{zoom} ),
        %{ $self->_map_hash_extras },
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

1;
