package FixMyStreet::Cobrand::Philadelphia;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

sub council_area { return 'Philadelphia'; }
sub council_url { return 'philadelphia'; }
sub get_geocoder { 'Philadelphia' }
sub map_type { 'MasterMap' }

sub disable_resend_button { 1 }

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

sub bypass_password_checks { 1 }