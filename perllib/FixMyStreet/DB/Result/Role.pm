use utf8;
package FixMyStreet::DB::Result::Role;

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
__PACKAGE__->table("roles");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "roles_id_seq",
  },
  "body_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 1 },
  "permissions",
  { data_type => "text[]", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("roles_body_id_name_key", ["body_id", "name"]);
__PACKAGE__->belongs_to(
  "body",
  "FixMyStreet::DB::Result::Body",
  { id => "body_id" },
  { is_deferrable => 0, on_delete => "CASCADE,", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "user_roles",
  "FixMyStreet::DB::Result::UserRole",
  { "foreign.role_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2019-05-23 18:03:28
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:KkzVQZuzExH8PhZLJsnZgg

__PACKAGE__->many_to_many( users => 'user_roles', 'user' );

1;
