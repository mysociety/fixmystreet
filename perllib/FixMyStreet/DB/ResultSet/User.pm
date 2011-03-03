package FixMyStreet::DB::ResultSet::User;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;

=head2 confirm_user_from_token

    $user = $rs->confirm_user_from_token( $token );

Given a token retrieve it from the database, find the user it relates to and
confirm them. Return the user an the end. If anything goes wrong return undef.

Delete the token afterwards.

See also the ::Result::User method 'create_confirm_token'

=cut

sub confirm_user_from_token {
    my $self = shift;
    my $token_string = shift || return;

    # retrieve the token or return
    my $token_rs = $self->result_source->schema->resultset('Token');
    my $token_obj =
      $token_rs->find( { scope => 'user_confirm', token => $token_string, } )
      || return;

    # find the user related to the token
    my $user = $self->find( { email => $token_obj->data->{email} } );

    # If we found a user confirm them and delete the token - in transaction
    $self->result_source->schema->txn_do(
        sub {
            $user->update( { is_confirmed => 1 } ) if $user;
            $token_obj->delete;
        }
    );

    # return the user (possibly undef if none found)
    return $user;
}

1;
