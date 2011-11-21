#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Warn;
use FixMyStreet::App;

use FindBin;
use lib "$FindBin::Bin/../perllib";
use lib "$FindBin::Bin/../commonlib/perllib";

use_ok( 'Open311' );

my $o = Open311->new();
ok $o, 'created object';

my $err_text = <<EOT
<?xml version="1.0" encoding="utf-8"?><errors><error><code>400</code><description>Service Code cannot be null -- can't proceed with the request.</description></error></errors>
EOT
;

is $o->_process_error( $err_text ), "400: Service Code cannot be null -- can't proceed with the request.\n", 'error text parsing';
is $o->_process_error( '503 - service unavailable' ), 'unknown error', 'error text parsing of bad error';

my $o2 = Open311->new( endpoint => 'http://192.168.50.1/open311/', jurisdiction => 'example.org' );

my $u = FixMyStreet::App->model('DB::User')->new( { email => 'test@example.org', name => 'A User' } );

my $p = FixMyStreet::App->model('DB::Problem')->new( {
    latitude => 1,
    longitude => 1,
    title => 'title',
    detail => 'detail',
    user => $u,
} );

my $expected_error = qr{.*request failed: 500 Can.t connect to 192.168.50.1:80 \([^)]*\).*};

warning_like {$o2->send_service_request( $p, { url => 'http://example.com/' }, 1 )} $expected_error, 'warning generated on failed call';

done_testing();
