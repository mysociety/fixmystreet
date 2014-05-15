use strict; use warnings;

use Test::More;
use Test::LongString;
use Test::MockTime ':all';

use Open311::Endpoint;
use Data::Dumper;
use JSON;

use t::open311::endpoint::Endpoint2;

my $endpoint = t::open311::endpoint::Endpoint2->new;
my $json = JSON->new;

subtest "POST OK" => sub {
    diag "Serves as sanity test of subclassing, as well as preparing our data";
    # TODO, refactor repeated code lifted from t/open311/endpoint.t

    set_fixed_time('2014-01-01T12:00:00Z');
    my $res = $endpoint->run_test_request( 
        POST => '/requests.json', 
        api_key => 'test',
        service_code => 'POT',
        address_string => '22 Acacia Avenue',
        first_name => 'Bob',
        last_name => 'Mould',
        'attribute[depth]' => 100,
        'attribute[shape]' => 'triangle',
    );
    ok $res->is_success, 'valid request'
        or diag $res->content;

    is_deeply $json->decode($res->content),
        [ {
            "service_notice" => "This is a test service",
            "service_request_id" => 0
        } ], 'correct json returned';

    set_fixed_time('2014-02-01T12:00:00Z');
    $res = $endpoint->run_test_request( 
        POST => '/requests.xml', 
        api_key => 'test',
        service_code => 'POT',
        address_string => '22 Acacia Avenue',
        first_name => 'Bob',
        last_name => 'Mould',
        'attribute[depth]' => 100,
        'attribute[shape]' => 'triangle',
    );

    ok $res->is_success, 'valid request'
        or diag $res->content;
};

subtest "GET Service Request Updates" => sub {

    my $res = $endpoint->run_test_request( GET => '/servicerequestupdates.xml', );
    ok $res->is_success, 'valid request'
        or diag $res->content;
    my $xml = <<CONTENT;
<?xml version="1.0" encoding="utf-8"?>
<service_requests>
</service_requests>
CONTENT

    is_string $res->content, $xml, 'xml string ok'
        or diag $res->content;
};

restore_time();
done_testing;
