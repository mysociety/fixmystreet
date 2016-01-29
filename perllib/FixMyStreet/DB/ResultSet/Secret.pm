package FixMyStreet::DB::ResultSet::Secret;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;

sub get {
    my $rs = shift;
    return $rs->first->secret;
}

1;
