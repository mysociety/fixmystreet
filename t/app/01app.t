#!/usr/bin/env perl

use strict;
use warnings;

package FixMyStreet::Cobrand::Tester;
use parent 'FixMyStreet::Cobrand::FiksGataMi';
sub front_stats_data { { new => 0, fixed => 0, updates => 12345 } }

package main;

use Test::More;
use Catalyst::Test 'FixMyStreet::App';
use charnames ':full';
use Encode qw(encode);

ok( request('/')->is_success, 'Request should succeed' );

SKIP: {
FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'tester' ],
}, sub {
    skip 'Test will not pass on Mac OS', 1 if $^O eq 'darwin';

    my $page = get('/');
    my $num = encode('UTF-8', "12\N{NO-BREAK SPACE}345");
    like $page, qr/$num/;
};
}

done_testing();
