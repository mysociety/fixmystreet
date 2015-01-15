# FixMyStreet:Map::GoogleOL
# Google maps on FixMyStreet, using OpenLayers.
#
# Copyright (c) 2013 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::GoogleOL;
use parent 'FixMyStreet::Map::OSM';

use strict;

sub map_type {
    return '""';
}

sub map_template {
    return 'google-ol';
}

1;
