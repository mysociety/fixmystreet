package FixMyStreet::DB::Result::Problem;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->table("problem");
__PACKAGE__->add_columns(
    "id",
    {
        data_type         => "integer",
        is_auto_increment => 1,
        is_nullable       => 0,
        sequence          => "problem_id_seq",
    },
    "postcode",
    { data_type => "text", is_nullable => 0 },
    "council",
    { data_type => "text", is_nullable => 1 },
    "areas",
    { data_type => "text", is_nullable => 0 },
    "category",
    { data_type => "text", default_value => "Other", is_nullable => 0 },
    "title",
    { data_type => "text", is_nullable => 0 },
    "detail",
    { data_type => "text", is_nullable => 0 },
    "photo",
    { data_type => "bytea", is_nullable => 1 },
    "used_map",
    { data_type => "boolean", is_nullable => 0 },
    "name",
    { data_type => "text", is_nullable => 0 },
    "phone",
    { data_type => "text", is_nullable => 0 },
    "anonymous",
    { data_type => "boolean", is_nullable => 0 },
    "created",
    {
        data_type     => "timestamp",
        default_value => \"ms_current_timestamp()",
        is_nullable   => 0,
    },
    "confirmed",
    { data_type => "timestamp", is_nullable => 1 },
    "state",
    { data_type => "text", is_nullable => 0 },
    "lang",
    { data_type => "text", default_value => "en-gb", is_nullable => 0 },
    "service",
    { data_type => "text", default_value => "", is_nullable => 0 },
    "cobrand",
    { data_type => "text", default_value => "", is_nullable => 0 },
    "cobrand_data",
    { data_type => "text", default_value => "", is_nullable => 0 },
    "lastupdate",
    {
        data_type     => "timestamp",
        default_value => \"ms_current_timestamp()",
        is_nullable   => 0,
    },
    "whensent",
    { data_type => "timestamp", is_nullable => 1 },
    "send_questionnaire",
    { data_type => "boolean", default_value => \"true", is_nullable => 0 },
    "latitude",
    { data_type => "double precision", is_nullable => 0 },
    "longitude",
    { data_type => "double precision", is_nullable => 0 },
    "user_id",
    { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
    "user",
    "FixMyStreet::DB::Result::User",
    { id            => "user_id" },
    { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

# Created by DBIx::Class::Schema::Loader v0.07010 @ 2011-03-15 17:03:37
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:jpuxH2vKnvhlYYjy6Qjbaw

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
