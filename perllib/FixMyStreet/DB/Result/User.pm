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
    { data_type => "text", default_value => "", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint( "users_email_key", ["email"] );
__PACKAGE__->has_many(
    "problems",
    "FixMyStreet::DB::Result::Problem",
    { "foreign.user_id" => "self.id" },
    { cascade_copy      => 0, cascade_delete => 0 },
);

# Created by DBIx::Class::Schema::Loader v0.07010 @ 2011-03-15 17:03:37
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:LAenO7w6lzCJyPUeosnLTw

1;
