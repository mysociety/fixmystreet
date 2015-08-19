use utf8;
package FixMyStreet::DB::Result::AlertSent;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("FilterColumn", "InflateColumn::DateTime", "EncodedColumn");
__PACKAGE__->table("alert_sent");
__PACKAGE__->add_columns(
  "alert_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "parameter",
  { data_type => "text", is_nullable => 1 },
  "whenqueued",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->belongs_to(
  "alert",
  "FixMyStreet::DB::Result::Alert",
  { id => "alert_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2015-08-13 16:33:38
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:/+Vodu8VJxJ0EY9P3Qjjjw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
