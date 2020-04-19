package FixMyStreet::Cobrand::Philadelphia;
use parent 'FixMyStreet::Cobrand::Default';

use strict;
use warnings;

sub get_geocoder { 'Philadelphia' }


sub on_map_default_status { 'open' }

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'grey' if $p->is_closed;
    return 'green' if $p->is_fixed;
    return 'yellow' if $p->state eq 'confirmed';
    return 'orange'; # all the other `open_states` like "in progress"
}

sub path_to_pin_icons {
    return '/cobrands/philadelphia/images/';
}
