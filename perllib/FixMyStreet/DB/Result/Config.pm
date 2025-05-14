use utf8;
package FixMyStreet::DB::Result::Config;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components(
  "FilterColumn",
  "+FixMyStreet::DB::JSONBColumn",
  "FixMyStreet::InflateColumn::DateTime",
  "FixMyStreet::EncodedColumn",
);
__PACKAGE__->table("config");
__PACKAGE__->add_columns(
  "key",
  { data_type => "text", is_nullable => 0 },
  "value",
  { data_type => "jsonb", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("key");


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2025-05-16 10:36:27
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:QKFFdj7P9P/W7j3ogGAtiQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
