package FixMyStreet::DB::Result::Config;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("FilterColumn", "InflateColumn::DateTime", "EncodedColumn");
__PACKAGE__->table("config");
__PACKAGE__->add_columns(
  "key",
  { data_type => "text", is_nullable => 0 },
  "value",
  { data_type => "text", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("key");


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2012-01-04 14:33:24
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:lu582Dve+qT4AWSIaVWzvQ

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
