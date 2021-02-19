# FixMyStreet:Map::GoogleOL
# Google maps on FixMyStreet, using OpenLayers.
#
# Copyright (c) 2013 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::GoogleOL;
use Moo;
extends 'FixMyStreet::Map::OSM';

has '+map_type' => ( default => '' );
has '+map_template' => ( default => 'google-ol' );

sub map_javascript {
    my $google_maps_url = "https://maps.googleapis.com/maps/api/js?v=3";
    my $key = FixMyStreet->config('GOOGLE_MAPS_API_KEY');
    $google_maps_url .= "&key=$key" if $key;
    [
        $google_maps_url,
        '/vendor/OpenLayers/OpenLayers.google.js',
        '/js/map-OpenLayers.js',
        '/js/map-google-ol.js',
    ]
}

1;
