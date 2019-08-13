package FixMyStreet::SendReport::Triage;

use Moo;

BEGIN { extends 'FixMyStreet::SendReport'; }

sub send {
    my $self = shift;
    my ( $row, $h ) = @_;

    $row->update({
        state => 'for triage'
    });

    $self->success(1);

    return 0;
}

1;
