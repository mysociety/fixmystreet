use utf8;
package FixMyStreet::DB::Result::Property;

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
__PACKAGE__->table("property");
__PACKAGE__->add_columns(
  "uprn",
  { data_type => "text", is_nullable => 0 },
  "discount_date",
  { data_type => "date", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("uprn");


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2026-07-02 15:32:37
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:T/5ZNoXmWxvT/n2aWq/5SQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
