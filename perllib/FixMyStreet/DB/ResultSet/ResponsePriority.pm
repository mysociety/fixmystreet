package FixMyStreet::DB::ResultSet::ResponsePriority;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;
use Moo;

with('FixMyStreet::Roles::DB::ContactExtra');

sub join_table {
    return 'contact_response_priorities';
}

sub map_extras {
    my ($rs, $params, @ts) = @_;
    my $current = $params->{problem} && $params->{problem}->response_priority_id || 0;
    return
        map { { id => $_->id, name => $_->name } }
        grep { !$_->deleted || $_->id == $current }
        @ts;
}

1;
