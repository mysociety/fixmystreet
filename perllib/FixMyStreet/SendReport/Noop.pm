package FixMyStreet::SendReport::Noop;

use Moo;

BEGIN { extends 'FixMyStreet::SendReport'; }

sub send {
    my $self = shift;
    $self->error( 'No-op' );
}

1;
