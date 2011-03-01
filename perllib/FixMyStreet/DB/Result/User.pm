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
    { data_type => "text", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint( "users_email_key", ["email"] );

# Created by DBIx::Class::Schema::Loader v0.07009 @ 2011-03-01 15:43:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:KZssayknEGFoV7seVdHp+w

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
