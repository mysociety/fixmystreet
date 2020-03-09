package FixMyStreet::Map::UKCouncilWMTS;
use base 'FixMyStreet::Map::WMTSBase';

use strict;

sub zoom_parameters {
    my $self = shift;
    my $params = {
        zoom_levels    => scalar $self->scales,
        default_zoom   => $self->default_zoom,
        min_zoom_level => 0,
        id_offset      => 0,
    };
    return $params;
}

sub tile_parameters {
    my $self = shift;
    my $params = {
        urls            => $self->urls,
        layer_names     => $self->layer_names,
        wmts_version    => '1.0.0',
        layer_style     => 'default',
        matrix_set      => 'default028mm',
        suffix          => '.png', # appended to tile URLs
        size            => 256, # pixels
        dpi             => 96,
        inches_per_unit => 39.37, # BNG uses metres
        projection      => 'EPSG:27700',
        origin_x        => -5220400.0,
        origin_y        => 4470200.0,
    };
    return $params;
}

# Reproject a WGS84 lat/lon into BNG easting/northing
sub reproject_from_latlon($$$) {
    my ($self, $lat, $lon) = @_;
    # do not try to reproject if we have no co-ordindates as convert breaks
    return (0.0, 0.0) if $lat == 0 && $lon == 0;
    my ($x, $y) = Utils::convert_latlon_to_en($lat, $lon);
    return ($x, $y);
}

# Reproject a BNG easting/northing into WGS84 lat/lon
sub reproject_to_latlon($$$) {
    my ($self, $x, $y) = @_;
    return (0,0) if $x<0 || $y<0;
    my ($lat, $lon) = Utils::convert_en_to_latlon($x, $y);
    return ($lat, $lon);
}

sub map_template { 'wmts' }

1;
