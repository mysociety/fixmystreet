# FixMyStreet:Map::Buckinghamshire
# More JavaScript, for street assets

package FixMyStreet::Map::Buckinghamshire;
use base 'FixMyStreet::Map::UKCouncilWMTS';

use strict;

sub default_zoom { 8; }

sub urls { [ 'https://maps.buckscc.gov.uk/arcgis/rest/services/Basemapping2018/MapServer/WMTS/tile' ] }

sub layer_names{ [ 'Basemapping2018' ] }

sub scales {
    my $self = shift;
    my @scales = (
        '1000000',
        '500000',
        '250000',
        '125000',
        '64000',
        '32000',
        '16000',
        '8000',
        '4000',
        '2000',
        '1000',
    );
    return @scales;

}

sub copyright {
    return '&copy; BCC';
}

sub map_template { 'buckinghamshire' }

sub map_javascript { [
    '/vendor/OpenLayers/OpenLayers.wmts.js',
    '/vendor/OpenLayers.Projection.OrdnanceSurvey.js',
    '/js/map-OpenLayers.js',
    '/js/map-wmts-base.js',
    '/js/map-wmts-buckinghamshire.js',
    '/cobrands/fixmystreet/assets.js',
    '/cobrands/fixmystreet-uk-councils/roadworks.js',
    '/cobrands/buckinghamshire/js.js',
    '/cobrands/buckinghamshire/assets.js',
] }

1;
