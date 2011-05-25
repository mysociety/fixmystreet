#!/usr/bin/perl
#
# FixMyStreet:Map::BingOL
# Bing maps on FixMyStreet, using OpenLayers.
#
# Copyright (c) 2011 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::BingOL;
use base 'FixMyStreet::Map::OSM';

use strict;

use constant ZOOM_LEVELS    => 5;
use constant MIN_ZOOM_LEVEL => 13;

sub header_js {
    return '
<!-- <script type="text/javascript" src="http://ecn.dev.virtualearth.net/mapcontrol/mapcontrol.ashx?v=7.0&mkt=en-GB"></script> -->
<script type="text/javascript" src="/jslib/OpenLayers-2.10/OpenLayers.js"></script>
<script type="text/javascript" src="/js/map-OpenLayers.js"></script>
<script type="text/javascript" src="/js/map-bing-ol.js"></script>
';
}

# Is set by the JavaScript
sub map_type {
    return '""';
}

sub copyright {
    return _('Map contains Ordnance Survey data &copy; Crown copyright and database right 2010. Microsoft');
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
            "http://a.os.openstreetmap.org/sv/$z/" . ($x-1) . "/" . ($y-1) . ".png",
            "http://b.os.openstreetmap.org/sv/$z/$x/" . ($y-1) . ".png",
            "http://c.os.openstreetmap.org/sv/$z/" . ($x-1) . "/$y.png",
            "http://os.openstreetmap.org/sv/$z/$x/$y.png",
        ];
    } else {
        return [
            "http://ecn.t0.tiles.virtualearth.net/tiles/r" . get_quadkey($x-1, $y-1, $z) . ".png?g=587&productSet=mmOS",
            "http://ecn.t1.tiles.virtualearth.net/tiles/r" . get_quadkey($x,   $y-1, $z) . ".png?g=587&productSet=mmOS",
            "http://ecn.t2.tiles.virtualearth.net/tiles/r" . get_quadkey($x-1, $y,   $z) . ".png?g=587&productSet=mmOS",
            "http://ecn.t3.tiles.virtualearth.net/tiles/r" . get_quadkey($x,   $y,   $z) . ".png?g=587&productSet=mmOS",
        ];
    }
}

1;
