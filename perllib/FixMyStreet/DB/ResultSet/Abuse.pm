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
use JSON::MaybeXS;
use LWP::UserAgent;
use Try::Tiny;

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
    my $domain;
    if ($email) {
        $email = lc $email;
        ($domain) = $email =~ m{ @ (.*) \z }x;
        push @check, $email, $domain;
    }
    if ($phone) {
        push @check, $phone;
    }
    my $existing = $rs->search( { email => \@check } )->first;
    return !$existing->safe if $existing;

    my $check = usercheck($domain);
    if ($check eq 'bad') {
        $rs->create({ email => $domain, safe => 0 });
        return 1;
    } elsif ($check eq 'good') {
        $rs->create({ email => $domain, safe => 1 });
    }
    return 0;
}

=head2 usercheck

Returns true if we should check UserCheck and the check
comes back positive for a domain that is disposable/blocked.

=cut

sub usercheck {
    my $domain = shift;

    my $api_key = FixMyStreet->config('CHECK_USERCHECK');
    return "off" unless $api_key;

    my $url = "https://api.usercheck.com/domain/$domain";
    my $ua = LWP::UserAgent->new;
    $ua->timeout(2);
    $ua->default_header(User_Agent => 'FixMyStreet/1.0', Authorization => "Bearer $api_key");
    my $response = $ua->get($url);
    my $check = try { decode_json($response->decoded_content) };
    return "fail" if !$check || $check->{status} != 200;
    return $check->{disposable} || $check->{blocklisted} ? "bad" : "good";
}

1;
