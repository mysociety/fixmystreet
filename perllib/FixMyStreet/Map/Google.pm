#!/usr/bin/perl
#
# FixMyStreet:Map::Google
# Google maps on FixMyStreet.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Map::Google;

use strict;
use mySociety::Web qw(ent);

sub header_js {
    return '
<script type="text/javascript" src="http://maps.google.com/maps/api/js?sensor=false"></script>
<script type="text/javascript" src="/js/map-google.js"></script>
';
}

# display_map C PARAMS
# PARAMS include:
# latitude, longitude for the centre point of the map
# TYPE is 1 if the map is clickable, 0 otherwise.
# PINS is array of pins to show, location and colour
sub display_map {
    my ($self, $c, %params) = @_;
    $params{pre} ||= '';

    my @pins;
    foreach my $pin (@{$params{pins}}) {
        $pin->[3] ||= '';
        push @pins, "[ $pin->[0], $pin->[1], '$pin->[2]', '$pin->[3]' ]";
    }
    my $pins_js = join(",\n", @pins);

    my $out = '';
    my $copyright = _('Map contains Ordnance Survey data &copy; Crown copyright and database right 2010.');
    $out .= <<EOF;
<script type="text/javascript">
var fixmystreet = {
    'latitude': $params{latitude},
    'longitude': $params{longitude},
    'pins': [ $pins_js ]
}
</script>
<div id="map_box">
    $params{pre}
    <div id="map"></div>
    <p id="copyright">$copyright</p>
EOF
    return $out;
}

1;
