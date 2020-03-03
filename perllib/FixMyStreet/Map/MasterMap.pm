# FixMyStreet:Map::MasterMap
#
# A combination of FMS OS maps and our own tiles

package FixMyStreet::Map::MasterMap;
use base 'FixMyStreet::Map::FMS';

use strict;

use constant ZOOM_LEVELS => 7;

sub map_template { 'fms' }

sub map_javascript { [
    '/vendor/OpenLayers/OpenLayers.wfs.js',
    '/js/map-OpenLayers.js',
    '/js/map-bing-ol.js',
    '/js/map-fms.js',
    '/js/map-mastermap.js',
] }

sub map_tiles {
    my ( $self, %params ) = @_;
    my ( $x, $y, $z ) = ( $params{x_tile}, $params{y_tile}, $params{zoom_act} );
    if ($z >= 17) {
        my $layer = FixMyStreet->config('STAGING_SITE') ? 'mastermap-staging' : 'mastermap';
        my $base = "//%stilma.mysociety.org/$layer/%d/%d/%d.png";
        return [
            sprintf($base, 'a.', $z, $x-1, $y-1),
            sprintf($base, 'b.', $z, $x, $y-1),
            sprintf($base, 'c.', $z, $x-1, $y),
            sprintf($base, '', $z, $x, $y),
        ];
    } else {
        return $self->SUPER::map_tiles(%params);
    }
}

1;

