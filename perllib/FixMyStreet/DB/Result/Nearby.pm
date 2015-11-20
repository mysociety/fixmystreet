package FixMyStreet::DB::Result::Nearby;

# Thanks to http://www.perlmonks.org/?node_id=633800

use strict;
use warnings;

use base 'DBIx::Class::Core';
use Moo;
use namespace::clean -except => [ 'meta' ];

__PACKAGE__->table( 'NONE' );
__PACKAGE__->add_columns(
  "problem_id",
  { data_type => "integer", is_nullable => 0 },
  "distance",
  { data_type => "double precision", is_nullable => 0 },
);
__PACKAGE__->belongs_to(
  "problem",
  "FixMyStreet::DB::Result::Problem",
  { id => "problem_id" },
  { is_deferrable => 1 },
);

# Make a new ResultSource based on the User class
__PACKAGE__->result_source_instance
    ->name( \'problem_find_nearby(?,?,?)' );

1;
