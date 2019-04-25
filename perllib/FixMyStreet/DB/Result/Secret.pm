use utf8;
package FixMyStreet::DB::Result::Secret;

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
__PACKAGE__->table("secret");
__PACKAGE__->add_columns("secret", { data_type => "text", is_nullable => 0 });


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2019-04-25 12:03:14
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:IjH+I3GvgYgLyG+rliQVxg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
