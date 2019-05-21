# FixMyStreet:Map::Hounslow
# Hounslow use their own tiles on their cobrand

package FixMyStreet::Map::Hounslow;
use base 'FixMyStreet::Map::UKCouncilWMTS';

use strict;

sub default_zoom { 10; }

sub urls { [ 'https://gis.ringway.co.uk/server/rest/services/Hosted/HounslowOSBasemap/MapServer/WMTS/tile' ] }

sub layer_names { [ 'Hosted_HounslowOSBasemap' ] }

sub scales {
    my $self = shift;
    my @scales = (
        '600000',
        '500000',
        '400000',
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


sub copyright {
    return 'Contains Ordnance Survey data &copy; Crown copyright and database rights 2019 OS. Use of this data is subject to <a href="/about/mapterms">terms and conditions</a>.';
}


sub map_javascript { [
    '/vendor/OpenLayers/OpenLayers.wmts.js',
    '/vendor/OpenLayers.Projection.OrdnanceSurvey.js',
    '/js/map-OpenLayers.js',
    '/js/map-wmts-base.js',
    '/js/map-wmts-hounslow.js',
    '/cobrands/fixmystreet-uk-councils/roadworks.js',
    '/cobrands/fixmystreet/assets.js',
    '/cobrands/hounslow/js.js',
    '/cobrands/hounslow/assets.js',
] }

1;
