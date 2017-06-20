package FixMyStreet::DB::ResultSet::DefectType;
use base 'DBIx::Class::ResultSet';

use strict;
use warnings;
use Moo;
use HTML::Entities;

with('FixMyStreet::Roles::ContactExtra');

sub join_table {
    return 'contact_defect_types';
}

sub map_extras {
    my ($rs, @ts) = @_;
    return map {
        my $meta = $_->get_extra_metadata();
        my %extra = map { $_ => encode_entities($meta->{$_}) } keys %$meta;
        {
            id => $_->id,
            name => encode_entities($_->name),
            extra => \%extra
        }
    } @ts;
}

1;
