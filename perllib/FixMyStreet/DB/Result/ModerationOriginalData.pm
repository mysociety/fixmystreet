use utf8;
package FixMyStreet::DB::Result::ModerationOriginalData;

=head1 NAME

FixMyStreet::DB::Result::ModerationOriginalData

=head1 DESCRIPTION

Stores the original data for problems/comments before any moderation.

This data could alternatively have been placed:

 - in problem/comments tables.  This would add text/binary fields to the workhorse
 of FMS's DB structure, as well as making the classes themselves more complex.  Adding
 the columns to the main tables would also require either duplicating the data in every
 case, or keeping track of whether or not to look for the backed up data.  The logic
 of keeping this in a separate table (and only if the record is ever moderated) is more
 appealing.

 - in the moderation_log tables.  Because there may be multiple events (and indeed, the
 first implementation is to only act on a particular type of modification at a time)
 the query logic to find the original data is more complex than a single might_have
 record.

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->table("moderation_original_data");
__PACKAGE__->load_components("InflateColumn::DateTime");

__PACKAGE__->add_columns(
  "id", {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "moderation_log_id_seq",
  },

  "problem_id", {
      data_type => "integer", is_nullable => 0
  },
  "comment_id", {
      data_type => "integer", is_nullable => 1
  },

  "title", {
      data_type => "text", is_nullable => 0
  },
  "detail", {
      data_type => "text", is_nullable => 0
  },
  "photo", {
      data_type => "bytea", is_nullable => 1
  },
  "anonymous", {
      data_type => "boolean", is_nullable => 0
  },

  "created", {
    data_type     => "timestamp",
    default_value => \"ms_current_timestamp()",
    is_nullable   => 0,
  },
);

__PACKAGE__->set_primary_key("id");

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
