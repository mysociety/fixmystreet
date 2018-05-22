package FixMyStreet::DB::ResultSet::DefectType;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;
use Moo;

with('FixMyStreet::Roles::ContactExtra');

sub join_table {
    return 'contact_defect_types';
}

sub map_extras {
    my ($rs, @ts) = @_;
    return map {
        my $meta = $_->get_extra_metadata();
        my %extra = map { $_ => $meta->{$_} } keys %$meta;
        {
            id => $_->id,
            name => $_->name,
            extra => \%extra
        }
    } @ts;
}

1;
