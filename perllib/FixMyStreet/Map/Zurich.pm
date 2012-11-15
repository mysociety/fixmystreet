#!/usr/bin/perl
#
# FixMyStreet:Map::Zurich
# Zurich have their own tileserver serving aerial photos instead
# of street maps.
#
# Copyright (c) 2012 UK Citizens Online Democracy. All rights reserved.
# Email: steve@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::Zurich;
use base 'FixMyStreet::Map::FMS';

use strict;

sub map_type {
    return 'OpenLayers.Layer.WMTS';
}

sub map_template {
	return 'zurich';
}

sub base_tile_url {
    return 'http://www.wmts.stadt-zuerich.ch/Luftbild/MapServer/WMTS/tile/';
}

# TODO - totally wrong probably - how do we actually do this?
sub map_tiles {
    my ( $self, %params ) = @_;
    my ( $x, $y, $z ) = ( $params{x_tile}, $params{y_tile}, $params{zoom_act} );
    my $tile_url = $self->base_tile_url();
    return [
        "$tile_url/$z/" . ($x - 1) . "/" . ($y - 1),
        "$tile_url/$z/$x/" . ($y - 1),
        "$tile_url/$z/" . ($x - 1) . "/$y",
        "$tile_url/$z/$x/$y",
    ];
}

1;