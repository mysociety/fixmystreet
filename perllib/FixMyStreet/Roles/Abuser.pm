package FixMyStreet::Roles::Abuser;

use Moo::Role;

=head2 is_from_abuser

    $bool = $alert->is_from_abuser(  );

Returns true if the user's email or its domain is listed in the 'abuse' table.

=cut

sub is_from_abuser {
    my $self = shift;

    # get the domain
    my $email = $self->user->email;
    my ($domain) = $email =~ m{ @ (.*) \z }x;

    # search for an entry in the abuse table
    my $abuse_rs = $self->result_source->schema->resultset('Abuse');

    return
         $abuse_rs->find( { email => $email } )
      || $abuse_rs->find( { email => $domain } )
      || undef;
}

1;
