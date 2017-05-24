package FixMyStreet::DB::ResultSet::ResponsePriority;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;
use Moo;
use HTML::Entities;

with('FixMyStreet::Roles::ContactExtra');

sub join_table {
    return 'contact_response_priorities';
}

sub map_extras {
    my ($rs, @ts) = @_;
    return map { { id => $_->id, name => encode_entities($_->name) } } @ts;
}

1;
