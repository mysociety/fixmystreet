package FixMyStreet::DB::Result::User;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->table("users");
__PACKAGE__->add_columns(
    "id",
    {
        data_type         => "integer",
        is_auto_increment => 1,
        is_nullable       => 0,
        sequence          => "users_id_seq",
    },
    "email",
    { data_type => "text", is_nullable => 0 },
    "name",
    { data_type => "text", is_nullable => 1 },
    "password",
    { data_type => "text", is_nullable => 1 },
    "is_confirmed",
    { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint( "users_email_key", ["email"] );

# Created by DBIx::Class::Schema::Loader v0.07009 @ 2011-03-03 10:05:03
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:4dpBN1I88nB1BYtHT/AfKA

=head2 create_confirm_token

    $token = $user->create_confirm_token();

Create a token that can be emailed to the user. When it is returned it can be
used to confirm that the email address works.

See also the ::ResultSet::User method 'confirm_user_from_token'.

=cut

sub create_confirm_token {
    my $self = shift;

    my $token_rs = $self->result_source->schema->resultset('Token');

    my $token_obj = $token_rs->create(
        {
            scope => 'user_confirm',            #
            data => { email => $self->email }
        }
    );

    return $token_obj->token;
}

1;
