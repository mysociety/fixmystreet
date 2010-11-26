#!/usr/bin/perl
#
# FixMyStreet:Map
# Adding the ability to have different maps on FixMyStreet.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map;

use strict;

use constant TILE_WIDTH => 250;
use constant TIF_SIZE_M => 5000;
use constant TIF_SIZE_PX => 5000;
use constant SCALE_FACTOR => TIF_SIZE_M / (TIF_SIZE_PX / TILE_WIDTH);
use constant TILE_TYPE => 'streetview';

use FixMyStreet::Map::Tilma::Original;

sub display_map {
    my ($q, %params) = @_;
    $params{copyright} = _('Map contains Ordnance Survey data &copy; Crown copyright and database right 2010.');
    return _display_map($q, %params);
}

1;
