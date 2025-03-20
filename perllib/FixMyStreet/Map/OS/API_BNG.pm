package FixMyStreet::Map::OS::API_BNG;

use Moo;
extends 'FixMyStreet::Map::OS::OML';

has '+min_zoom_level' => ( is => 'lazy', default => sub {
    return $_[0]->in_northern_ireland_box ? 13 : 6;
});

has '+min_zoom_level_any' => ( is => 'ro', default => 0 );

has os_map_type => ( is => 'ro', default => 'OpenLayers.Layer.OSMapsBNG' );

has '+map_type' => ( is => 'lazy', default => sub {
    return $_[0]->in_northern_ireland_box ? 'OpenLayers.Layer.OSM.Mapnik' : $_[0]->os_map_type;
});

sub map_javascript { [
    '/vendor/OpenLayers/OpenLayers.wfs.js',
    '/js/map-OpenLayers.js',
    '/js/map-OpenStreetMap.js',
    '/js/map-os-bng.js',
] }

has '+layer' => ( default => sub { 'Road_27700' } );

sub tile_parameters { { origin_x => -238375, origin_y => 1376256, } }

sub resolutions { ( 896, 448, 224, 112, 56, 28, 14, 7, 7/2, 7/4, 7/8, 7/16, 7/32, 7/64 ) }

sub latlon_to_tile($$$$) {
    my ($self, $lat, $lon, $zoom) = @_;
    if ($self->in_northern_ireland_box) {
        return $self->SUPER::latlon_to_tile($lat, $lon, $zoom);
    }
    my ($x, $y) = eval { Utils::convert_latlon_to_en($lat, $lon) };
    my $tile_params = $self->tile_parameters;
    my $res = ($self->resolutions)[$zoom];
    my $fx = ( $x - $tile_params->{origin_x} ) / ($res * 256);
    my $fy = ( $tile_params->{origin_y} - $y ) / ($res * 256);
    return ( $fx, $fy );
}

sub tile_to_latlon {
    my ($self, $fx, $fy, $zoom) = @_;
    if ($self->in_northern_ireland_box) {
        return $self->SUPER::tile_to_latlon($fx, $fy, $zoom);
    }
    my $tile_params = $self->tile_parameters;
    my $res = ($self->resolutions)[$zoom];
    my $x = $fx * $res * 256 + $tile_params->{origin_x};
    my $y = $tile_params->{origin_y} - $fy * $res * 256;
    my ($lat, $lon) = Utils::convert_en_to_latlon($x, $y);
    return ( $lat, $lon );
}

1;
