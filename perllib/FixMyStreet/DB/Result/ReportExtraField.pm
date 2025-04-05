use utf8;
package FixMyStreet::DB::Result::ReportExtraField;

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
__PACKAGE__->table("report_extra_fields");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "report_extra_fields_id_seq",
  },
  "name",
  { data_type => "text", is_nullable => 0 },
  "cobrand",
  { data_type => "text", is_nullable => 1 },
  "language",
  { data_type => "text", is_nullable => 1 },
  "extra",
  { data_type => "jsonb", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2024-10-21 23:30:33
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:IU8WZrwpQ2UxbIVaII3B5A

use Moo;
use namespace::clean -except => [ 'meta' ];

with 'FixMyStreet::Roles::DB::Extra';

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
