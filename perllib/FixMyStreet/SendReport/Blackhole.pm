package FixMyStreet::SendReport::Blackhole;

use Moo;

BEGIN { extends 'FixMyStreet::SendReport'; }

=head2 send

Immediately marks the report as successfully sent, but doesn't actually send
it anywhere.

=cut

sub send {
    my $self = shift;
    $self->success(1);
    return 0;
}

1;
