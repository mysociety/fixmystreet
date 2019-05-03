use utf8;
package FixMyStreet::DB::Result::Questionnaire;

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
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2019-04-25 12:06:39
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:AWRb6itjsVkG5VUDRmBTIg

use Moo;
use namespace::clean -except => [ 'meta' ];

sub marks_fixed {
    my $self = shift;
    my $new_fixed = FixMyStreet::DB::Result::Problem->fixed_states()->{$self->new_state};
    my $old_fixed = FixMyStreet::DB::Result::Problem->fixed_states()->{$self->old_state};
    return $new_fixed && !$old_fixed;
}

1;
