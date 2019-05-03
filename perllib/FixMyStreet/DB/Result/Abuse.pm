use utf8;
package FixMyStreet::DB::Result::Abuse;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components(
  "FilterColumn",
  "FixMyStreet::InflateColumn::DateTime",
  "FixMyStreet::EncodedColumn",
);
__PACKAGE__->table("abuse");
__PACKAGE__->add_columns("email", { data_type => "text", is_nullable => 0 });
__PACKAGE__->set_primary_key("email");


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2019-04-25 12:06:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:6XdWpymMMUEC4WT9Yh0RLw

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
