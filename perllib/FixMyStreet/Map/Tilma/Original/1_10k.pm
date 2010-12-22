#!/usr/bin/perl
#
# FixMyStreet:Map
# Adding the ability to have different maps on FixMyStreet.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map;

use strict;

use constant TILE_WIDTH => 254;
use constant TIF_SIZE_M => 5000;
use constant TIF_SIZE_PX => 7874;
use constant SCALE_FACTOR => TIF_SIZE_M / (TIF_SIZE_PX / TILE_WIDTH);
use constant TILE_TYPE => '10k-full';

use FixMyStreet::Map::Tilma::Original;

sub display_map {
    my ($q, %params) = @_;
    $params{copyright} = _('&copy; Crown copyright. All rights reserved. Ministry of Justice 100037819&nbsp;2008.');
    $params{watermark} = 1;
    return _display_map($q, %params);
}

1;
