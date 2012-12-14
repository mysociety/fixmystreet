use utf8;
package FixMyStreet::DB::Result::BodyArea;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("FilterColumn", "InflateColumn::DateTime", "EncodedColumn");
__PACKAGE__->table("body_areas");
__PACKAGE__->add_columns(
  "body_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "area_id",
  { data_type => "integer", is_nullable => 0 },
);
__PACKAGE__->belongs_to(
  "body",
  "FixMyStreet::DB::Result::Body",
  { id => "body_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07017 @ 2012-12-14 17:54:33
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:jTU6Nu/MQEvg9o8Hf5YQUQ

 __PACKAGE__->set_primary_key(__PACKAGE__->columns);

1;
