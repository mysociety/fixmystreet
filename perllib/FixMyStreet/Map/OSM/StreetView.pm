#!/usr/bin/perl
#
# FixMyStreet:Map::OSM::StreetView
# OSM StreetView maps on FixMyStreet.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::OSM::StreetView;
use base 'FixMyStreet::Map::OSM';

use strict;

sub header_js {
    return '
<script type="text/javascript" src="/jslib/OpenLayers-2.10/OpenLayers.js"></script>
<script type="text/javascript" src="/js/map-OpenLayers.js"></script>
<script type="text/javascript" src="/js/map-streetview.js"></script>
';
}

sub map_type {
    return '""';
}

sub base_tile_url {
    return 'os.openstreetmap.org/sv';
}

sub copyright {
    return _('Map contains Ordnance Survey data &copy; Crown copyright and database right 2010.');
}

1;
