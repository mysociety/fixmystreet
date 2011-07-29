package FixMyStreet::DB::Result::Open311conf;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("FilterColumn", "InflateColumn::DateTime", "EncodedColumn");
__PACKAGE__->table("open311conf");
__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_nullable => 0 },
  "area_id",
  { data_type => "integer", is_nullable => 0 },
  "endpoint",
  { data_type => "text", is_nullable => 0 },
  "jurisdiction",
  { data_type => "text", is_nullable => 1 },
  "api_key",
  { data_type => "text", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("open311conf_area_id_key", ["area_id"]);


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2011-07-29 17:47:55
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:e7DwO1HQwldHk/94RvQj6A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
