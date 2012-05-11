#!/usr/bin/perl
#
# FixMyStreet:Map::Bromley
# Bromley have slightly different tiles, with trees etc.
#
# Copyright (c) 2012 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::Bromley;
use base 'FixMyStreet::Map::FMS';

use strict;

sub map_type {
    my $self = shift;
    return '"' . $self->map_tile_base . '"';
}

sub map_tile_base {
    return "tilma.mysociety.org/bromley";
}

1;
