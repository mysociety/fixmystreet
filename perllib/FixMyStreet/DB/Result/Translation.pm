use utf8;
package FixMyStreet::DB::Result::Translation;

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
__PACKAGE__->table("translation");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "translation_id_seq",
  },
  "tbl",
  { data_type => "text", is_nullable => 0 },
  "object_id",
  { data_type => "integer", is_nullable => 0 },
  "col",
  { data_type => "text", is_nullable => 0 },
  "lang",
  { data_type => "text", is_nullable => 0 },
  "msgstr",
  { data_type => "text", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "translation_tbl_object_id_col_lang_key",
  ["tbl", "object_id", "col", "lang"],
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2019-04-25 12:06:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:EsseG51ZpQa5QYHPCpkL8A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
