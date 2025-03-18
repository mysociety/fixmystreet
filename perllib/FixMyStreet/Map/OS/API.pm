# FixMyStreet:Map::OS::API
# Display OS Maps API tiles (zoom levels 7-16, 17-20 if premium)

package FixMyStreet::Map::OS::API;

use Moo;
extends 'FixMyStreet::Map::OSM';
with 'FixMyStreet::Map::OS::Base';

has '+map_type' => ( default => 'OpenLayers.Layer.OSMaps' );

sub map_javascript { [
    '/vendor/OpenLayers/OpenLayers.wfs.js',
    '/js/map-OpenLayers.js',
    FixMyStreet->config('BING_MAPS_API_KEY') ? ('/js/map-bing-ol.js') : (),
    '/js/map-os.js',
] }

has '+copyright' => ( default => sub {
    my $self = shift;
    my $year = 1900 + (localtime)[5];
    my $licence = $self->licence || '';
    "Contains National Highways and OS data &copy; Crown copyright and database rights $year $licence";
});

sub map_tiles {
    my ( $self, %params ) = @_;
    my ( $x, $y, $z ) = ( $params{x_tile}, $params{y_tile}, $params{zoom_act} );
    if ($params{aerial}) {
        return $self->SUPER::map_tiles(%params);
    } else {
        my $tile_url = sprintf($self->os_tile_url, $self->layer);
        my $key = $self->key;
        return [
            "$tile_url/$z/" . ($x-1) . "/" . ($y-1) . ".png?key=$key",
            "$tile_url/$z/$x/" . ($y-1) . ".png?key=$key",
            "$tile_url/$z/" . ($x-1) . "/$y.png?key=$key",
            "$tile_url/$z/$x/$y.png?key=$key",
        ];
    }
}

1;
