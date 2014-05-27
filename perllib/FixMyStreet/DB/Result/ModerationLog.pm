use utf8;
package FixMyStreet::DB::Result::ModerationLog;

=head1 NAME

FixMyStreet::DB::Result::ModerationLog

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<moderation_log>

=cut

__PACKAGE__->table("moderation_log");
__PACKAGE__->load_components("InflateColumn::DateTime");

__PACKAGE__->add_columns(
  "id", {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "moderation_log_id_seq",
  },
  "moderation_object", { 
      data_type => "text", is_nullable => 0
  },
  "moderation_type", {
      data_type => "text", is_nullable => 0
  },
  "user_id", {
      data_type => "integer", is_nullable => 0
  },
  "problem_id", {
      data_type => "integer", is_nullable => 0
  },
  "comment_id", {
      data_type => "integer", is_nullable => 1
  },
  "whenedited", {
    data_type     => "timestamp",
    default_value => \"ms_current_timestamp()",
    is_nullable   => 0,
  },
  "reason", {
      data_type => "text", is_nullable => 0
  }
);

__PACKAGE__->set_primary_key("id");

__PACKAGE__->belongs_to(
  "user",
  "FixMyStreet::DB::Result::User",
  { id => "user_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

__PACKAGE__->belongs_to(
  "problem",
  "FixMyStreet::DB::Result::Problem",
  { id => "problem_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

__PACKAGE__->belongs_to(
  "comment",
  "FixMyStreet::DB::Result::Comment",
  { id => "comment_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION",
    join_type => 'left' },
);

1;
