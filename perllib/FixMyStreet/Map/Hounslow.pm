# FixMyStreet:Map::Hounslow
# Hounslow use their own tiles on their cobrand

package FixMyStreet::Map::Hounslow;
use base 'FixMyStreet::Map::UKCouncilWMTS';

use strict;

sub default_zoom { 5; }

sub urls { [ 'https://gis.ringway.co.uk/server/rest/services/Hosted/HounslowOSBasemap/MapServer/WMTS/tile' ] }

sub layer_names { [ 'Hosted_HounslowOSBasemap' ] }

sub scales {
    my $self = shift;
    my @scales = (
        # The first 5 levels don't load and are really zoomed-out, so
        #  they're not included here.
        # '600000',
        # '500000',
        # '400000',
        # '300000',
        # '200000',
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

sub zoom_parameters {
    my $self = shift;
    my $params = {
        zoom_levels    => scalar $self->scales,
        default_zoom   => $self->default_zoom,
        min_zoom_level => 0,
        id_offset      => 5, # see note above about zoom layers we've skipped
    };
    return $params;
}

sub copyright {
    return 'Contains Ordnance Survey data &copy; Crown copyright and database rights 2019 OS. Use of this data is subject to <a href="/about/mapterms">terms and conditions</a>.';
}


sub map_javascript { [
    '/vendor/OpenLayers/OpenLayers.wmts.js',
    '/js/map-OpenLayers.js',
    '/js/map-wmts-base.js',
    '/js/map-wmts-hounslow.js',
] }

1;
