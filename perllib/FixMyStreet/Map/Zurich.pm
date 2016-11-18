# FixMyStreet:Map::Zurich
# Zurich have their own tileserver.

package FixMyStreet::Map::Zurich;
use base 'FixMyStreet::Map::WMTSBase';

use strict;
use Geo::Coordinates::CH1903Plus;

sub zoom_parameters {
    my $self = shift;
    my $params = {
        zoom_levels    => scalar $self->scales,
        default_zoom   => 5,
        min_zoom_level => 0,
        id_offset      => 2,
    };
    return $params;
}

sub tile_parameters {
    my $self = shift;
    my $params = {
        urls            => [
          'https://www.gis.stadt-zuerich.ch/maps/rest/services/tiled95/LuftbildHybrid/MapServer/WMTS/tile',
          'https://www.gis.stadt-zuerich.ch/maps/rest/services/tiled95/Stadtplan3D/MapServer/WMTS/tile'
        ],
        layer_names     => [ 'LuftbildHybrid', 'Stadtplan3D' ],
        wmts_version    => '1.0.0',
        layer_style     => 'default',
        matrix_set      => 'default028mm',
        suffix          => '.jpg', # appended to tile URLs
        size            => 512, # pixels
        dpi             => 96,
        inches_per_unit => 39.3701, # BNG uses metres
        projection      => 'EPSG:2056',
        # The original tile origin values from the getCapabilities call are
        # -27386400.0/31814500.0, but this results in the map tile being offset
        # slightly. These corrected values were figured out manually by
        # trial and error...
        origin_x        => -27386322.5,
        origin_y        => 31814423.0,
    };
    return $params;
}

sub scales {
    my $self = shift;
    my @scales = (
        # The two highest zoom levels are pretty much useless so they're disabled.
        # '256000', # resolution 67.73346880027094
        # '128000', # resolution 33.86673440013547
        '64000', # resolution 16.933367200067735
        '32000', # resolution 8.466683600033868
        '16000', # resolution 4.233341800016934
        '8000', # resolution 2.116670900008467
        '4000', # resolution 1.0583354500042335
        '2000', # resolution 0.5291677250021167
        '1000', # resolution 0.26458386250105836
        '500', # resolution 0.13229193125052918
        '250', # resolution 0.06614596562526459
    );
    return @scales;
}

sub copyright {
    return '&copy; Stadt Z&uuml;rich';
}

sub map_template { 'zurich' }


# Reproject a WGS84 lat/lon into Swiss easting/northing
sub reproject_from_latlon($$$) {
    my ($self, $lat, $lon) = @_;
    my ($x, $y) = Geo::Coordinates::CH1903Plus::from_latlon($lat, $lon);
    return ($x, $y);
}

# Reproject a Swiss easting/northing into WGS84 lat/lon
sub reproject_to_latlon($$$) {
    my ($self, $x, $y) = @_;
    my ($lat, $lon) = Geo::Coordinates::CH1903Plus::to_latlon($x, $y);
    return ($lat, $lon);
}

1;
