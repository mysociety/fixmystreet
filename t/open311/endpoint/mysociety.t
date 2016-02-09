use strict; use warnings;

use Test::More;
use Test::LongString;
use Test::MockTime ':all';

use Open311::Endpoint;
use Data::Dumper;
use JSON::MaybeXS;

use t::open311::endpoint::Endpoint2;

my $endpoint = t::open311::endpoint::Endpoint2->new;

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

    is_deeply decode_json($res->content),
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
<service_request_updates>
</service_request_updates>
CONTENT

    my $update_0_xml = <<CONTENT;
<?xml version="1.0" encoding="utf-8"?>
<service_request_updates>
  <request_update>
    <description>Fixed</description>
    <media_url></media_url>
    <service_request_id>0</service_request_id>
    <status>closed</status>
    <update_id>1</update_id>
    <updated_datetime>2014-01-01T13:00:00Z</updated_datetime>
  </request_update>
</service_request_updates>
CONTENT

my $updates_xml = <<CONTENT;
<?xml version="1.0" encoding="utf-8"?>
<service_request_updates>
  <request_update>
    <description>Fixed</description>
    <media_url></media_url>
    <service_request_id>0</service_request_id>
    <status>closed</status>
    <update_id>1</update_id>
    <updated_datetime>2014-01-01T13:00:00Z</updated_datetime>
  </request_update>
  <request_update>
    <description>Have investigated. Looks tricky!</description>
    <media_url></media_url>
    <service_request_id>1</service_request_id>
    <status>open</status>
    <update_id>2</update_id>
    <updated_datetime>2014-03-01T13:00:00Z</updated_datetime>
  </request_update>
</service_request_updates>
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
        my $request = $endpoint->get_request(0);
        $request->add_update(
            update_id => 1,
            status => 'closed',
            description => 'Fixed',
        );

        is $request->status, 'closed', 'Status updated';

        my $before='2014-01-01T12:00:00Z';
        my $after ='2014-01-01T14:00:00Z';

        for my $scenario (
            [ '', $update_0_xml, 'Basic test', ],
            [ "?start_date=$before", $update_0_xml, 'start date' ],
            [ "?end_date=$after", $update_0_xml, 'end_date' ],
            [ "?start_date=$before&end_date=$after", $update_0_xml, 'both dates' ],
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
        my $request = $endpoint->get_request(1);
        $request->add_update(
            update_id => 2,
            description => 'Have investigated. Looks tricky!',
        );

        for my $scenario (
            [ '', $updates_xml, 'Both reports', ],
            [ "?end_date=2014-01-01T14:00:00Z", $update_0_xml, 'end_date before second update' ],
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
