# FixMyStreet:Map::Bing
# Bing maps on FixMyStreet.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::Bing;

use strict;

# display_map C PARAMS
# PARAMS include:
# latitude, longitude for the centre point of the map
# CLICKABLE is set if the map is clickable
# PINS is array of pins to show, location and colour
sub display_map {
    my ($self, $c, %params) = @_;
    $c->stash->{map} = {
        %params,
        type => 'bing',
        key => mySociety::Config::get('BING_MAPS_API_KEY'),
    };
}

1;
