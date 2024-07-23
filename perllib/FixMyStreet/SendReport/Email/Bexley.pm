package FixMyStreet::SendReport::Email::Bexley;

use Moo;

BEGIN { extends 'FixMyStreet::SendReport::Email'; }

has use_verp => ( is => 'ro', default => 0 );

=head2 send_from

Waste emails come from council

=cut

sub send_from {
    my ( $self, $row ) = @_;

    if ( $row->cobrand_data eq 'waste' ) {
        my $cobrand = $row->get_cobrand_logged;
        return [ $cobrand->do_not_reply_email, $cobrand->council_name ];
    }

    $self->SUPER::send_from($row);
}

1;
