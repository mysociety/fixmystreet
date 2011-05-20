package FixMyStreet::DB::Result::Questionnaire;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("FilterColumn");
__PACKAGE__->table("questionnaire");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "questionnaire_id_seq",
  },
  "problem_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "whensent",
  { data_type => "timestamp", is_nullable => 0 },
  "whenanswered",
  { data_type => "timestamp", is_nullable => 1 },
  "ever_reported",
  { data_type => "boolean", is_nullable => 1 },
  "old_state",
  { data_type => "text", is_nullable => 1 },
  "new_state",
  { data_type => "text", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "problem",
  "FixMyStreet::DB::Result::Problem",
  { id => "problem_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2011-05-20 12:11:12
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:6CunhdbfTFdNnjhurkV0Gg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
