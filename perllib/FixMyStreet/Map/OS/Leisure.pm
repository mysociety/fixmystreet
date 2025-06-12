package FixMyStreet::Map::OS::Leisure;

use Moo;
extends 'FixMyStreet::Map::OS::API_BNG';

has '+zoom_levels' => ( is => 'lazy', default => sub {
    $_[0]->premium ? 8 : 6
} );

has oml_tile_url => ( is => 'ro', default => 'https://%stilma.mysociety.org/mapcache/gmaps/oml@osmaps' );

has '+oml_zoom_switch' => ( default => 10 );

1;
