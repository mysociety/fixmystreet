package FixMyStreet::DB::JSONBColumn;

use strict;
use warnings;
use JSON::MaybeXS;

my $JSON;

sub register_column {
    my ($self, $column, $info, @rest) = @_;

    $self->next::method($column, $info, @rest);

    return unless ($info->{data_type} || '') eq 'jsonb';

    $JSON ||= JSON->new->allow_nonref->canonical;

    $self->filter_column(
        $column => {
            filter_from_storage => sub {
                my ($self, $value) = @_;
                return undef unless defined $value;
                return $JSON->decode($value);
            },
            filter_to_storage => sub {
                my ($self, $value) = @_;
                return $JSON->encode($value);
            },
        }
    );
}

1;

__END__

=head1 NAME

FixMyStreet::DB::JSONBColumn

=head1 DESCRIPTION

Causes 'jsonb' type columns to automatically be JSON encoded and
decoded.

=cut
