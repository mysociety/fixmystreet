# FixMyStreet:Map::Bristol
# Bristol use their own tiles on their cobrand

package FixMyStreet::Map::Bristol;
use base 'FixMyStreet::Map::UKCouncilWMTS';

use strict;

sub default_zoom { 5; }

sub urls { [ 'https://maps.bristol.gov.uk/arcgis/rest/services/base/2019_Q2_BCC_96dpi/MapServer/WMTS/tile' ] }

sub layer_names { [ '2019_Q2_BCC_96dpi' ] }

sub scales {
    my $self = shift;
    my @scales = (
        '192000', # resolution: 50.800101600203206
        '96000', # resolution: 25.400050800101603
        '48000', # resolution: 12.700025400050801
        '24000', # resolution: 6.350012700025401
        '12000', # resolution: 3.1750063500127004
        '6000', # resolution: 1.5875031750063502
        '3000', # resolution: 0.7937515875031751
        '1250', # resolution: 0.33072982812632296
        '750', # resolution: 0.19843789687579377
    );
    return @scales;
}

sub copyright {
    return '&copy; BCC';
}

sub map_javascript { [
    '/vendor/OpenLayers/OpenLayers.wmts.js',
    '/js/map-OpenLayers.js',
    '/js/map-wmts-base.js',
    '/js/map-wmts-bristol.js',
] }

1;
