#!/usr/bin/perl
#
# FixMyStreet:Map::FMS
# Bing and OS StreetView maps on FixMyStreet, using OpenLayers.
#
# Copyright (c) 2011 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::FMS;
use base 'FixMyStreet::Map::OSM';

use strict;

# Is set by the JavaScript
sub map_type {
    return '""';
}

sub map_template {
    return 'fms';
}

sub copyright {
    return '';
}

sub get_quadkey {
    my ($x, $y, $z) = @_;
    my $key = '';
    for (my $i = $z; $i > 0; $i--) {
        my $digit = 0;
        my $mask = 1 << ($i - 1);
        $digit++ if ($x & $mask) != 0;
        $digit += 2 if ($y & $mask) != 0;
        $key .= $digit;
    }
    return $key;
}

sub map_tile_base {
    "http://%stilma.mysociety.org/sv/%d/%d/%d.png";
}

sub map_tiles {
    my ($self, $x, $y, $z) = @_;
    if ($z >= 16) {
        my $tile_base = $self->map_tile_base;
        return [
            sprintf($tile_base, 'a.', $z, $x-1, $y-1),
            sprintf($tile_base, 'b.', $z, $x, $y-1),
            sprintf($tile_base, 'c.', $z, $x-1, $y),
            sprintf($tile_base, '', $z, $x, $y),
        ];
    } else {
        my $url = "g=701";
        $url .= "&productSet=mmOS" if $z > 10;
        return [
            "//ecn.t0.tiles.virtualearth.net/tiles/r" . get_quadkey($x-1, $y-1, $z) . ".png?$url",
            "//ecn.t1.tiles.virtualearth.net/tiles/r" . get_quadkey($x,   $y-1, $z) . ".png?$url",
            "//ecn.t2.tiles.virtualearth.net/tiles/r" . get_quadkey($x-1, $y,   $z) . ".png?$url",
            "//ecn.t3.tiles.virtualearth.net/tiles/r" . get_quadkey($x,   $y,   $z) . ".png?$url",
        ];
    }
}

1;
