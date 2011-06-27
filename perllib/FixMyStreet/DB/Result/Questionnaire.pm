package FixMyStreet::DB::Result::Questionnaire;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->load_components("FilterColumn", "InflateColumn::DateTime", "EncodedColumn");
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


# Created by DBIx::Class::Schema::Loader v0.07010 @ 2011-06-23 15:49:48
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:QNFqqCg6J4SFlg4zwm7TWw

use DateTime::TimeZone;

my $tz = DateTime::TimeZone->new( name => "local" );

sub whensent_local {
    my $self = shift;

    return $self->whensent
      ? $self->whensent->set_time_zone($tz)
      : $self->whensent;
}

sub whenanswered_local {
    my $self = shift;

    return $self->whenanswered
      ? $self->whenanswered->set_time_zone($tz)
      : $self->whenanswered;
}

1;
