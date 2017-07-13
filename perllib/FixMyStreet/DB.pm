package FixMyStreet::DB;

use strict;
use warnings;
use FixMyStreet::DB::Schema;

my $schema;

sub schema { $schema ||= FixMyStreet::DB::Schema->clone }

sub resultset { shift->schema->resultset(@_) }

1;
