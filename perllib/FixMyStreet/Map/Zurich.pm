#!/usr/bin/perl
#
# FixMyStreet:Map::Zurich
# Zurich have their own tileserver.
#
# Copyright (c) 2012 UK Citizens Online Democracy. All rights reserved.
# Email: steve@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::Zurich;
use base 'FixMyStreet::Map::OSM';

use strict;

sub map_type {
    return 'OpenLayers.Layer.WMTS';
}

sub map_template {
	return 'zurich';
}

sub base_tile_url {
    return 'http://www.wmts.stadt-zuerich.ch/Luftbild/MapServer/WMTS/tile/1.0.0/Luftbild/default/default028mm';
}

sub map_tiles {
    my ( $self, %params ) = @_;
    my ( $x, $y, $z ) = ( $params{x_tile}, $params{y_tile}, $params{zoom_act} );
    my $tile_url = $self->base_tile_url();
    return [
        "$tile_url/$z/" . ($x - 1) . "/" . ($y - 1) . ".jpg",
        "$tile_url/$z/$x/" . ($y - 1) . ".jpg",
        "$tile_url/$z/" . ($x - 1) . "/$y.jpg",
        "$tile_url/$z/$x/$y.jpg",
    ];
}

1;