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
    default_value => \"ms_current_timestamp()",
    is_nullable   => 0,
  },
);
__PACKAGE__->belongs_to(
  "alert",
  "FixMyStreet::DB::Result::Alert",
  { id => "alert_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-09-10 17:11:54
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:COwsprqRSNZS1IxJrPYgMQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
