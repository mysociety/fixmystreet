package DBIx::Class::Helper::ResultSet::OrderBy;

use strict;
use warnings;

use parent 'DBIx::Class::ResultSet';

sub order_by {
    my ($self, $order) = @_;
    $order = { -desc => $1 } if $order =~ /^-(.*)/;
    $self->search(undef, { order_by => $order });
}

1;
