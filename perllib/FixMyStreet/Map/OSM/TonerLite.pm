#!/usr/bin/perl
#
# FixMyStreet:Map::OSM::TonerLite
# OSM TonerLite maps on FixMyStreet.
#
# Map tiles by <http://stamen.com> Stamen Design,
# under <http://creativecommons.org/licenses/by/3.0>CC BY 3.0.
# Data by <http://openstreetmap.org> OpenStreetMap,
# under <http://www.openstreetmap.org/copyright> ODbL.
#
# Copyright (c) 2014 UK Citizens Online Democracy. All rights reserved.
# Email: hakim@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::OSM::TonerLite;
use base 'FixMyStreet::Map::OSM';

use strict;

sub map_type {
    return 'OpenLayers.Layer.Stamen';
}

sub map_template {
    return 'osm-tonerlite';
}

sub copyright {
    'Map tiles by <a href="http://stamen.com">Stamen Design</a>, under <a href="http://creativecommons.org/licenses/by/3.0">CC BY 3.0</a>. Data by <a href="http://openstreetmap.org">OpenStreetMap</a>, under <a href="http://www.openstreetmap.org/copyright">ODbL</a>.'
}

1;
