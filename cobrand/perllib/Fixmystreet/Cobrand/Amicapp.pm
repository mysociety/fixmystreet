package FixMyStreet::Cobrand::Amicapp;
use base 'FixMyStreet::Cobrand::Default';

use strict;
use warnings;

sub country {
    return 'DO';
}

sub languages { [ 'es-do,Spanish,es_DO' ] }
sub language_override { 'es-do' }

sub admin_allow_user {
    my ( $self, $user ) = @_;
    return 1 if $user->is_superuser || $user->from_body;
}

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'green' if $p->is_closed || $p->is_fixed;
    return 'red' if $p->state eq 'confirmed';
    return 'yellow'; # all the other `open_states` like "in progress"
}


1;