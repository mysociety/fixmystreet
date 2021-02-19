# FixMyStreet:Map::Bromley
# Bromley have slightly different tiles, with trees etc.
#
# Copyright (c) 2012 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::Bromley;
use Moo;
extends 'FixMyStreet::Map::FMS';

has '+base_tile_url' => ( default => '//%stilma.mysociety.org/bromley' );

1;
