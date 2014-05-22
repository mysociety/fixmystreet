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

    my $empty_xml = <<CONTENT;
<?xml version="1.0" encoding="utf-8"?>
<service_requests>
</service_requests>
CONTENT

    my $report_0_xml = <<CONTENT;
<?xml version="1.0" encoding="utf-8"?>
<service_requests>
  <request>
    <address>22 Acacia Avenue</address>
    <address_id></address_id>
    <lat>0</lat>
    <lon>0</lon>
    <media_url></media_url>
    <requested_datetime>2014-01-01T12:00:00Z</requested_datetime>
    <service_code>POT</service_code>
    <service_name>Pothole Repairs</service_name>
    <service_request_id>0</service_request_id>
    <status>open</status>
    <updated_datetime>2014-01-01T13:00:00Z</updated_datetime>
    <zipcode></zipcode>
  </request>
</service_requests>
CONTENT

my $reports_xml = <<CONTENT;
<?xml version="1.0" encoding="utf-8"?>
<service_requests>
  <request>
    <address>22 Acacia Avenue</address>
    <address_id></address_id>
    <lat>0</lat>
    <lon>0</lon>
    <media_url></media_url>
    <requested_datetime>2014-01-01T12:00:00Z</requested_datetime>
    <service_code>POT</service_code>
    <service_name>Pothole Repairs</service_name>
    <service_request_id>0</service_request_id>
    <status>open</status>
    <updated_datetime>2014-01-01T13:00:00Z</updated_datetime>
    <zipcode></zipcode>
  </request>
  <request>
    <address>22 Acacia Avenue</address>
    <address_id></address_id>
    <lat>0</lat>
    <lon>0</lon>
    <media_url></media_url>
    <requested_datetime>2014-02-01T12:00:00Z</requested_datetime>
    <service_code>POT</service_code>
    <service_name>Pothole Repairs</service_name>
    <service_request_id>1</service_request_id>
    <status>open</status>
    <updated_datetime>2014-03-01T13:00:00Z</updated_datetime>
    <zipcode></zipcode>
  </request>
</service_requests>
CONTENT

    subtest 'No updates' => sub {
        my $res = $endpoint->run_test_request( GET => '/servicerequestupdates.xml', );
        ok $res->is_success, 'valid request' or diag $res->content;

        is_string $res->content, $empty_xml, 'xml string ok'
            or diag $res->content;
    };

    subtest 'Updated 1 ticket' => sub {
        # an agent updates the first ticket
        set_fixed_time('2014-01-01T13:00:00Z');
        $endpoint->get_request(0)->updated_datetime(DateTime->now());

        my $before='2014-01-01T12:00:00Z';
        my $after ='2014-01-01T14:00:00Z';

        for my $scenario (
            [ '', $report_0_xml, 'Basic test', ],
            [ "?start_date=$before", $report_0_xml, 'start date' ],
            [ "?end_date=$after", $report_0_xml, 'end_date' ],
            [ "?start_date=$before&end_date=$after", $report_0_xml, 'both dates' ],
            [ "?start_date=$after", $empty_xml, 'Not found if start date after update' ],
            [ "?end_date=$before", $empty_xml, 'Not found if end date before update' ] 
        ) {
            my ($query, $xml, $description) = @$scenario;

            my $res = $endpoint->run_test_request( GET => '/servicerequestupdates.xml' . $query, );
            ok $res->is_success, 'valid request' or diag $res->content;
            is_string $res->content, $xml, $description;
        }
    };

    subtest 'Updated another ticket' => sub {
        set_fixed_time('2014-03-01T13:00:00Z');
        $endpoint->get_request(1)->updated_datetime(DateTime->now());

        for my $scenario (
            [ '', $reports_xml, 'Both reports', ],
            [ "?end_date=2014-01-01T14:00:00Z", $report_0_xml, 'end_date before second update' ],
        ) {
            my ($query, $xml, $description) = @$scenario;

            my $res = $endpoint->run_test_request( GET => '/servicerequestupdates.xml' . $query, );
            ok $res->is_success, 'valid request' or diag $res->content;
            is_string $res->content, $xml, $description or diag $res->content;
        }
    };
};

restore_time();
done_testing;
