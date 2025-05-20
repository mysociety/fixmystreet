=head1 NAME

FixMyStreet::DB::ResultSet::Abuse

=head1 DESCRIPTION

Helper functions for querying the abuse table in the database

=head1 METHODS

=cut

package FixMyStreet::DB::ResultSet::Abuse;
use base 'FixMyStreet::DB::ResultSet';

use strict;
use warnings;

=head2 unsafe

Returns those entries with safe set to false.

=cut

sub unsafe {
    my $rs = shift;
    $rs = $rs->search({ safe => 0 });
    return $rs;
}

=head2 check

Given an email and/or phone number, query the abuse table to see
if they are present (plus the email's domain if email was given)
and return true if they are.

=cut

sub check {
    my ($rs, $email, $phone) = @_;

    my @check;
    if ($email) {
        my ($domain) = $email =~ m{ @ (.*) \z }x;
        push @check, $email, $domain;
    }
    if ($phone) {
        push @check, $phone;
    }
    my $existing = $rs->search( { email => \@check } )->first;
    return $existing ? !$existing->safe : 0;
}

1;
