#!/usr/bin/perl
#
# FixMyStreet:Map
# Adding the ability to have different maps on FixMyStreet.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::Tilma::Original::StreetView;
use base 'FixMyStreet::Map::Tilma::Original';

use strict;

sub tile_width   { return 250; }
sub tif_size_m   { return 5000; }
sub tif_size_px  { return 5000; }
sub scale_factor { return tif_size_m() / (tif_size_px() / tile_width()); }
sub tile_type    { return 'streetview'; }

sub copyright {
    return _('Map contains Ordnance Survey data &copy; Crown copyright and database right 2010.');
}

sub watermark {
    return 0;
}

1;
