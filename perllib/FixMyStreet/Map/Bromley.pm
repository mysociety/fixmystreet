# FixMyStreet:Map::Bromley
# Bromley have slightly different tiles, with trees etc.
#
# Copyright (c) 2012 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::Bromley;
use base 'FixMyStreet::Map::FMS';

use strict;

sub map_template { 'bromley' }

sub map_tile_base {
    '-', "https://%sfix.bromley.gov.uk/tilma/%d/%d/%d.png";
}

1;
