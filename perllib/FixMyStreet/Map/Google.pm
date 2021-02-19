# FixMyStreet:Map::Google
# Google maps on FixMyStreet.
#
# Copyright (c) 2013 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::Google;

use Moo;
extends 'FixMyStreet::Map::Base';

sub map_javascript { [
    "http://maps.googleapis.com/maps/api/js?sensor=false",
    '/js/map-google.js',
] }

sub generate_map_data {
    my ($self, %params) = @_;

    my $zoom_params = $self->calculate_zoom(%params);

    return {
        %params,
        %$zoom_params,
        type => 'google',
    };
}

1;
