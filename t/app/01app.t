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

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'tester' ],
}, sub {
    my $page = decode_utf8(get('/'));
    my $num = "12( | )345";
    like $page, qr/$num/;
};

subtest 'CSP header' => sub {
    my $res = request('/');
    is $res->header('Content-Security-Policy'), undef, 'None by default';

    FixMyStreet::override_config {
        CONTENT_SECURITY_POLICY => 1,
    }, sub {
        my $res = request('/');
        like $res->header('Content-Security-Policy'), qr/script-src 'self' 'unsafe-inline' 'nonce-[^']*' ; object-src 'none'; base-uri 'none'/,
            'Default CSP header if requested';
    };

    FixMyStreet::override_config {
        CONTENT_SECURITY_POLICY => 'www.example.org',
    }, sub {
        my $res = request('/');
        like $res->header('Content-Security-Policy'), qr/script-src 'self' 'unsafe-inline' 'nonce-[^']*' www.example.org; object-src 'none'; base-uri 'none'/,
            'With 3P domains if given';
    };

    FixMyStreet::override_config {
        CONTENT_SECURITY_POLICY => [ 'www.example.org' ],
    }, sub {
        my $res = request('/');
        like $res->header('Content-Security-Policy'), qr/script-src 'self' 'unsafe-inline' 'nonce-[^']*' www.example.org; object-src 'none'; base-uri 'none'/,
            'With 3P domains if given';
    };
};

done_testing();
