package FixMyStreet::DB::Result::Alert;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("FilterColumn");
__PACKAGE__->table("alert");
__PACKAGE__->add_columns(
    "id",
    {
        data_type         => "integer",
        is_auto_increment => 1,
        is_nullable       => 0,
        sequence          => "alert_id_seq",
    },
    "alert_type",
    { data_type => "text", is_foreign_key => 1, is_nullable => 0 },
    "parameter",
    { data_type => "text", is_nullable => 1 },
    "parameter2",
    { data_type => "text", is_nullable => 1 },
    "email",
    { data_type => "text", is_nullable => 0 },
    "confirmed",
    { data_type => "integer", default_value => 0, is_nullable => 0 },
    "lang",
    { data_type => "text", default_value => "en-gb", is_nullable => 0 },
    "cobrand",
    { data_type => "text", default_value => "", is_nullable => 0 },
    "cobrand_data",
    { data_type => "text", default_value => "", is_nullable => 0 },
    "whensubscribed",
    {
        data_type     => "timestamp",
        default_value => \"ms_current_timestamp()",
        is_nullable   => 0,
    },
    "whendisabled",
    { data_type => "timestamp", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");

# Created by DBIx::Class::Schema::Loader v0.07010 @ 2011-05-10 12:36:15
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:tfT1PBeEOwcLsQaX+HXSKA

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
