#!/usr/bin/perl
#
# FixMyStreet:Map::Tilma::1_10k_OL
# Using tilma.mysociety.org with OpenLayers
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::Tilma::OpenLayers;

use strict;

sub TILE_WIDTH()   { return $FixMyStreet::Map::map_class->tile_width;   }
sub SCALE_FACTOR() { return $FixMyStreet::Map::map_class->scale_factor; }
sub TILE_TYPE()    { return $FixMyStreet::Map::map_class->tile_type;    }

sub header_js {
    return '
<script type="text/javascript" src="/jslib/OpenLayers-2.10/OpenLayers.js"></script>
<script type="text/javascript" src="/js/map-OpenLayers.js"></script>
<script type="text/javascript" src="/js/map-tilma-ol.js"></script>
<script type="text/javascript" src="/js/OpenLayers.Projection.OrdnanceSurvey.js"></script>
';
}

# display_map C PARAMS
# PARAMS include:
# latitude, longitude for the centre point of the map
# TYPE is 1 if the map is clickable, 0 otherwise.
# PINS is array of pins to show, location and colour
sub display_map {
    my ($self, $c, %params) = @_;
    $c->stash->{map} = {
        %params,
        type => 'tilma/openlayers',
        tile_type => TILE_TYPE,
        tilewidth => TILE_WIDTH,
        watermark => $self->watermark(),
        copyright => $self->copyright(),
        maxResolution => SCALE_FACTOR / TILE_WIDTH,
    };
}

1;
