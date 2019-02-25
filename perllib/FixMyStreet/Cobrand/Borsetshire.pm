package FixMyStreet::Cobrand::Borsetshire;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

sub council_area_id { return 2608; }
sub council_area { return 'Borsetshire'; }
sub council_name { return 'Borsetshire County Council'; }
sub council_url { return 'demo'; }

sub example_places {
    return ( 'BS36 2NS', 'Coalpit Heath' );
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

sub enable_category_groups { 1 }

sub suggest_duplicates { 1 }

1;
