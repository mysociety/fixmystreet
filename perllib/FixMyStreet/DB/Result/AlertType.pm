use utf8;
package FixMyStreet::DB::Result::AlertType;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components(
  "FilterColumn",
  "FixMyStreet::InflateColumn::DateTime",
  "EncodedColumn",
);
__PACKAGE__->table("alert_type");
__PACKAGE__->add_columns(
  "ref",
  { data_type => "text", is_nullable => 0 },
  "head_sql_query",
  { data_type => "text", is_nullable => 0 },
  "head_table",
  { data_type => "text", is_nullable => 0 },
  "head_title",
  { data_type => "text", is_nullable => 0 },
  "head_link",
  { data_type => "text", is_nullable => 0 },
  "head_description",
  { data_type => "text", is_nullable => 0 },
  "item_table",
  { data_type => "text", is_nullable => 0 },
  "item_where",
  { data_type => "text", is_nullable => 0 },
  "item_order",
  { data_type => "text", is_nullable => 0 },
  "item_title",
  { data_type => "text", is_nullable => 0 },
  "item_link",
  { data_type => "text", is_nullable => 0 },
  "item_description",
  { data_type => "text", is_nullable => 0 },
  "template",
  { data_type => "text", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("ref");
__PACKAGE__->has_many(
  "alerts",
  "FixMyStreet::DB::Result::Alert",
  { "foreign.alert_type" => "self.ref" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2019-04-25 12:03:14
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:hLHv/QSFUvn5pVs2K2h2qQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
