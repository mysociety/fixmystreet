#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::MockModule;

use Utils::Email;

my $resolver = Test::MockModule->new('Net::DNS::Resolver');
$resolver->mock('send', sub {
    my ($self, $domain, $type) = @_;
    my @rrs;
    is $type, 'TXT';
    if ($domain eq '_dmarc.yahoo.com') {
        @rrs = (
            Net::DNS::RR->new(name => '_dmarc.yahoo.com', type => 'TXT', txtdata => 'v=DMARC1; p=reject'),
            Net::DNS::RR->new(name => '_dmarc.yahoo.com', type => 'A'),
        );
    } elsif ($domain eq 'cname.example.com') {
        @rrs = Net::DNS::RR->new(name => 'cname.example.com', type => 'TXT', txtdata => 'v=DMARC1; p=none; sp=quarantine');
    } elsif ($domain eq '_dmarc.example.net') {
        @rrs = Net::DNS::RR->new(name => '_dmarc.example.net', type => 'CNAME', cname => 'cname.example.com');
    } elsif ($domain eq '_dmarc.example.com') {
        @rrs = Net::DNS::RR->new(name => '_dmarc.example.com', type => 'TXT', txtdata => 'v=DMARC1; p=reject; sp=none');
    }
    my $pkt = Net::DNS::Packet->new;
    push @{$pkt->{answer}}, @rrs;
    return $pkt;
});

is Utils::Email::test_dmarc('BAD'), undef;
is Utils::Email::test_dmarc('test@yahoo.com'), 1;
is Utils::Email::test_dmarc('test@example.net'), undef;
is Utils::Email::test_dmarc('test@subdomain.yahoo.com'), 1, 'subdomain inherits parent';
is Utils::Email::test_dmarc('test@subdomain.example.net'), 1, 'subdomain parent has sp set';
is Utils::Email::test_dmarc('test@subdomain.example.com'), undef, 'subdomain parent has sp=none';
is Utils::Email::test_dmarc('test@subdomain.fixmystreet.com'), undef, 'subdomain and parent not there';

is Utils::Email::same_domain(['test@example.net', ''], [ ['to@example.net', ''], ['to@example.com', ''] ]), 1;
is Utils::Email::same_domain(['test@example.org', ''], [ ['to@example.net', ''] ]), '';

done_testing();
