package FixMyStreet::Map::Northamptonshire;
use base 'FixMyStreet::Map::WMSBase';

use strict;

sub default_zoom { 8; }

sub urls { [ 'https://maps.northamptonshire.gov.uk/interactivemappingwms/getmap.ashx' ] }

sub layer_names{ [ 'BaseMap' ] }

sub copyright {
    return '&copy; NCC';
}

sub scales {
    my $self = shift;
    my @scales = (
        '300000',
        '200000',
        '100000',
        '75000',
        '50000',
        '25000',
        '10000',
        '8000',
        '6000',
        '4000',
        '2000',
        '1000',
        '400',
    );
    return @scales;
}
sub tile_parameters {
    my $self = shift;
    my $params = {
        urls            => $self->urls,
        layer_names     => $self->layer_names,
        wms_version    => '1.1.1',
        layer_style     => 'default',
        format          => 'image/png', # appended to tile URLs
        size            => 256, # pixels
        dpi             => 96,
        inches_per_unit => 39.3701,
        projection      => 'EPSG:27700',
    };
    return $params;
}

sub zoom_parameters {
    my $self = shift;
    my $params = {
        zoom_levels    => scalar $self->scales,
        default_zoom   => 7,
        min_zoom_level => 1,
        id_offset      => 0,
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
    my ($lat, $lon) = Utils::convert_en_to_latlon($x, $y);
    return ($lat, $lon);
}

sub map_javascript { [
    '/vendor/OpenLayers/OpenLayers.wms.js',
    '/js/map-OpenLayers.js',
    '/js/map-wms-base.js',
    '/js/map-wms-northamptonshire.js',
] }

1;
