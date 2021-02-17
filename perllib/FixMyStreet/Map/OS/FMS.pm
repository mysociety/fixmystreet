# FixMyStreet:Map::OS::FMS
# Bing Maps zoomed out, OS Maps zoomed in

package FixMyStreet::Map::OS::FMS;

use Moo;
extends 'FixMyStreet::Map::FMS';
with 'FixMyStreet::Map::OS::Base';

# As OS Maps API only has one host, we can (ab)use the
# prefix to insert our chosen layer
has '+map_tile_prefix' => ( is => 'lazy', default => sub {
    my $layer = $_[0]->layer;
    [$layer, $layer, $layer, $layer]
} );

sub map_javascript {
    my $self = shift;
    my $js = $self->SUPER::map_javascript;
    push @$js, '/js/map-fms-os.js';
    return $js;
}

sub map_tiles {
    my ( $self, %params ) = @_;
    my $urls = $self->SUPER::map_tiles(%params);
    if ($urls->[0] =~ /api\.os\.uk/) {
        my $key = $self->key;
        $urls = [ map { $_ .= "?key=$key" } @$urls ];
    }
    return $urls;
}

1;

