package FixMyStreet::Map::HighwaysEngland;

use Moo;
extends 'FixMyStreet::Map::FMS';

has '+min_zoom_level' => ( default => 12 );

1;
