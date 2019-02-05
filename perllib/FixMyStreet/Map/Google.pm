# FixMyStreet:Map::Google
# Google maps on FixMyStreet.
#
# Copyright (c) 2013 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::Google;

use strict;
use FixMyStreet::Gaze;
use Utils;

use constant ZOOM_LEVELS    => 6;
use constant MIN_ZOOM_LEVEL => 13;

sub map_javascript { [
    "http://maps.googleapis.com/maps/api/js?sensor=false",
    '/js/map-google.js',
] }

# display_map C PARAMS
# PARAMS include:
# latitude, longitude for the centre point of the map
# CLICKABLE is set if the map is clickable
# PINS is array of pins to show, location and colour
sub display_map {
    my ($self, $c, %params) = @_;

    my $numZoomLevels = ZOOM_LEVELS;
    my $zoomOffset = MIN_ZOOM_LEVEL;
    if ($params{any_zoom}) {
        $numZoomLevels = 19;
        $zoomOffset = 0;
    }

    # Adjust zoom level dependent upon population density
    my $dist = $c->stash->{distance}
        || FixMyStreet::Gaze::get_radius_containing_population( $params{latitude}, $params{longitude} );
    my $default_zoom = $c->cobrand->default_map_zoom() ? $c->cobrand->default_map_zoom() : $numZoomLevels - 4;
    $default_zoom = $numZoomLevels - 3 if $dist < 10;

    # Map centre may be overridden in the query string
    $params{latitude} = Utils::truncate_coordinate($c->get_param('lat') + 0)
        if defined $c->get_param('lat');
    $params{longitude} = Utils::truncate_coordinate($c->get_param('lon') + 0)
        if defined $c->get_param('lon');
    $params{zoomToBounds} = $params{any_zoom} && !defined $c->get_param('zoom');

    my $zoom = defined $c->get_param('zoom') ? $c->get_param('zoom') + 0 : $default_zoom;
    $zoom = $numZoomLevels - 1 if $zoom >= $numZoomLevels;
    $zoom = 0 if $zoom < 0;
    $params{zoom_act} = $zoomOffset + $zoom;

    $c->stash->{map} = {
        %params,
        type => 'google',
        zoom => $zoom,
        zoomOffset => $zoomOffset,
        numZoomLevels => $numZoomLevels,
    };
}

1;
