#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

package FixMyStreet::Cobrand::Tester;
use parent 'FixMyStreet::Cobrand::FixaMinGata';
sub front_stats_data { { new => 0, fixed => 0, updates => 12345 } }

package main;

use Encode;
use Test::More;
use Catalyst::Test 'FixMyStreet::App';
use charnames ':full';

ok( request('/')->is_success, 'Request should succeed' );

SKIP: {
FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'tester' ],
}, sub {
    my $page = decode_utf8(get('/'));
    my $num = "12( | )345";
    like $page, qr/$num/;
};
}

done_testing();
