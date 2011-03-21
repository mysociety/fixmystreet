package FixMyStreet::DB::Result::Contact;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->table("contacts");
__PACKAGE__->add_columns(
    "area_id",
    { data_type => "integer", is_nullable => 0 },
    "category",
    { data_type => "text", default_value => "Other", is_nullable => 0 },
    "email",
    { data_type => "text", is_nullable => 0 },
    "confirmed",
    { data_type => "boolean", is_nullable => 0 },
    "deleted",
    { data_type => "boolean", is_nullable => 0 },
    "editor",
    { data_type => "text", is_nullable => 0 },
    "whenedited",
    { data_type => "timestamp", is_nullable => 0 },
    "note",
    { data_type => "text", is_nullable => 0 },
    "id",
    {
        data_type         => "integer",
        is_auto_increment => 1,
        is_nullable       => 0,
        sequence          => "contacts_id_seq",
    },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint( "contacts_area_id_category_idx",
    [ "area_id", "category" ] );

# Created by DBIx::Class::Schema::Loader v0.07010 @ 2011-03-21 16:25:05
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:zuvUDlmZI74jTjrSCb1RTQ

1;
