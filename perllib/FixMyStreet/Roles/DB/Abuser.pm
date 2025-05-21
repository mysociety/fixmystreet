package FixMyStreet::Roles::DB::Abuser;

use Moo::Role;

=head2 is_from_abuser

    $bool = $alert->is_from_abuser(  );

Returns true if the user's email/domain/phone is listed in the 'abuse' table.

=cut

sub is_from_abuser {
    my $self = shift;
    my $abuse_rs = $self->result_source->schema->resultset('Abuse');
    return $abuse_rs->check($self->user->email, $self->user->phone);
}

1;
