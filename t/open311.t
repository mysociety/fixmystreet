#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Warn;
use FixMyStreet::App;
use CGI::Simple;
use HTTP::Response;
use DateTime;

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

my $dt = DateTime->now();

my $user = FixMyStreet::App->model('DB::User')->new( {
    email => 'test@example.com',
} );

my $problem = FixMyStreet::App->model('DB::Problem')->new( {
    id => 80,
    external_id => 81,
    state => 'confirmed',
} );

my $comment = FixMyStreet::App->model('DB::Comment')->new( {
    id => 38362,
    user => $user,
    problem => $problem,
    anonymous => 0,
    text => 'this is a comment',
    confirmed => $dt,
} );

subtest 'testing posting updates' => sub {
    my $results = make_update_req( $comment, '<?xml version="1.0" encoding="utf-8"?><service_request_updates><request_update><update_id>248</update_id></request_update></service_request_updates>' );

    is $results->{ res }, 248, 'got update id';

    my $req = $o->test_req_used;

    my $c = CGI::Simple->new( $results->{ req }->content );

    is $c->param('description'), 'this is a comment', 'email correct';
    is $c->param('email'), 'test@example.com', 'email correct';
    is $c->param('status'), 'OPEN', 'status correct';
    is $c->param('service_request_id_ext'), 80, 'external request id correct';
    is $c->param('service_request_id'), 81, 'request id correct';
    is $c->param('public_anonymity_required'), 'FALSE', 'anon status correct';
    is $c->param('updated_datetime'), $dt, 'correct date';
};

foreach my $test (
    {
        desc => 'fixed is CLOSED',
        state => 'fixed',
        anon  => 0,
        status => 'CLOSED',
    },
    {
        desc => 'fixed - user is CLOSED',
        state => 'fixed - user',
        anon  => 0,
        status => 'CLOSED',
    },
    {
        desc => 'fixed - council is CLOSED',
        state => 'fixed - council',
        anon  => 0,
        status => 'CLOSED',
    },
    {
        desc => 'closed is CLOSED',
        state => 'closed',
        anon  => 0,
        status => 'CLOSED',
    },
    {
        desc => 'investigating is OPEN',
        state => 'investigating',
        anon  => 0,
        status => 'OPEN',
    },
    {
        desc => 'planned is OPEN',
        state => 'planned',
        anon  => 0,
        status => 'OPEN',
    },
    {
        desc => 'in progress is OPEN',
        state => 'in progress',
        anon  => 0,
        status => 'OPEN',
    },
    {
        desc => 'anonymous set to true',
        state => 'confirmed',
        anon  => 1,
        status => 'OPEN',
    },
) {
    subtest $test->{desc} => sub {
        $comment->problem->state( $test->{state} );
        $comment->anonymous( $test->{anon} );

        my $results = make_update_req( $comment, '<?xml version="1.0" encoding="utf-8"?><service_request_updates><request_update><update_id>248</update_id></request_update></service_request_updates>' );

        my $c = CGI::Simple->new( $results->{ req }->content );
        is $c->param('status'), $test->{status}, 'correct status';
        is $c->param('public_anonymity_required'), $test->{anon} ? 'TRUE' : 'FALSE', 'correct anonymity';
    };
}

subtest 'No update id in reponse' => sub {
    my $results;
    warning_like {
        $results = make_update_req( $comment, '<?xml version="1.0" encoding="utf-8"?><service_request_updates><request_update><update_id></update_id></request_update></service_request_updates>' )
    } qr/Failed to submit comment \d+ over Open311/, 'correct error message';

    is $results->{ res }, 0, 'No update_id is a failure';
};

subtest 'error reponse' => sub {
    my $results;
    warning_like {
        $results = make_update_req( $comment, '<?xml version="1.0" encoding="utf-8"?><errors><error><code>400</code><description>There was an error</description</error></errors>' )
    } qr/Failed to submit comment \d+ over Open311.*There was an error/, 'correct error messages';

    is $results->{ res }, 0, 'error in response is a failure';
};

done_testing();

sub make_update_req {
    my $comment = shift;
    my $xml = shift;

    my $o = Open311->new( test_mode => 1, end_point => 'http://localhost/o311' );

    my $test_res = HTTP::Response->new();
    $test_res->code( 200 );
    $test_res->message( 'OK' );
    $test_res->content( $xml );

    $o->test_get_returns( {
            'update.xml' => $test_res
    } );

    my $res = $o->post_service_request_update( $comment );

    my $req = $o->test_req_used;

    return { res => $res, req => $req };
}
