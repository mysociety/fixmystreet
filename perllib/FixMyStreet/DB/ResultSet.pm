package FixMyStreet::DB::ResultSet;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;

__PACKAGE__->load_components('Helper::ResultSet::OrderBy');

1;
