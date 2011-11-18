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

sub map_tiles {
    my ($self, $x, $y, $z) = @_;
    if ($z >= 16) {
        return [
            "http://a.tilma.mysociety.org/sv/$z/" . ($x-1) . "/" . ($y-1) . ".png",
            "http://b.tilma.mysociety.org/sv/$z/$x/" . ($y-1) . ".png",
            "http://c.tilma.mysociety.org/sv/$z/" . ($x-1) . "/$y.png",
            "http://tilma.mysociety.org/sv/$z/$x/$y.png",
        ];
    } else {
        my $url = "g=701";
        $url .= "&productSet=mmOS" if $z > 10;
        return [
            "http://ecn.t0.tiles.virtualearth.net/tiles/r" . get_quadkey($x-1, $y-1, $z) . ".png?$url",
            "http://ecn.t1.tiles.virtualearth.net/tiles/r" . get_quadkey($x,   $y-1, $z) . ".png?$url",
            "http://ecn.t2.tiles.virtualearth.net/tiles/r" . get_quadkey($x-1, $y,   $z) . ".png?$url",
            "http://ecn.t3.tiles.virtualearth.net/tiles/r" . get_quadkey($x,   $y,   $z) . ".png?$url",
        ];
    }
}

1;
