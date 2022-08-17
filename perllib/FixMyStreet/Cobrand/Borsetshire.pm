package FixMyStreet::Cobrand::Borsetshire;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

sub council_area_id { return 2608; }
sub council_area { return 'Borsetshire'; }
sub council_name { return 'Borsetshire County Council'; }
sub council_url { return 'demo'; }

sub enter_postcode_text {
    my ($self) = @_;
    return 'Enter a UK postcode, or street name and area';
}

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'grey' if $p->is_closed;
    return 'green' if $p->is_fixed;
    return 'yellow' if $p->state eq 'confirmed';
    return 'orange'; # all the other `open_states` like "in progress"
}

sub path_to_pin_icons {
    return '/cobrands/oxfordshire/images/';
}

sub send_questionnaires {
    return 0;
}

sub bypass_password_checks { 1 }

1;
