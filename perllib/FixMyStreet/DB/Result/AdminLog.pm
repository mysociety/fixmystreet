package FixMyStreet::DB::Result::AdminLog;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("FilterColumn", "InflateColumn::DateTime", "EncodedColumn");
__PACKAGE__->table("admin_log");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "admin_log_id_seq",
  },
  "admin_user",
  { data_type => "text", is_nullable => 0 },
  "object_type",
  { data_type => "text", is_nullable => 0 },
  "object_id",
  { data_type => "integer", is_nullable => 0 },
  "action",
  { data_type => "text", is_nullable => 0 },
  "whenedited",
  {
    data_type     => "timestamp",
    default_value => \"ms_current_timestamp()",
    is_nullable   => 0,
  },
);
__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2011-06-23 15:49:48
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:7427CuN3/6IL2GxiQDoWUA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
