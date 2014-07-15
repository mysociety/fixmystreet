use strict; use warnings;

use Test::More;
use Test::LongString;
use Test::MockTime ':all';

use Data::Dumper;
use JSON;

use Open311::Endpoint::Integration::Warwick;

my $endpoint = Open311::Endpoint::Integration::Warwick->new;
my $json = JSON->new;

subtest "GET Service List" => sub {
    my $res = $endpoint->run_test_request( GET => '/services.xml' );
    ok $res->is_success, 'xml success';
    my $expected = <<XML;
<?xml version="1.0" encoding="utf-8"?>
<services>
  <service>
    <description>Bridges</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>false</metadata>
    <service_code>BR</service_code>
    <service_name>Bridges</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>Carriageway Defect</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>false</metadata>
    <service_code>CD</service_code>
    <service_name>Carriageway Defect</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>Roads/Highways</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>false</metadata>
    <service_code>CD</service_code>
    <service_name>Roads/Highways</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>Drainage</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>false</metadata>
    <service_code>DR</service_code>
    <service_name>Drainage</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>Debris/Spillage</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>false</metadata>
    <service_code>DS</service_code>
    <service_name>Debris/Spillage</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>Fences</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>false</metadata>
    <service_code>FE</service_code>
    <service_name>Fences</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>Pavements</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>false</metadata>
    <service_code>F D</service_code>
    <service_name>Pavements</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>Gully &amp; Catchpits</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>false</metadata>
    <service_code>GC</service_code>
    <service_name>Gully &amp; Catchpits</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>Ice/Snow</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>false</metadata>
    <service_code>IS</service_code>
    <service_name>Ice/Snow</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>Mud &amp; Debris</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>false</metadata>
    <service_code>MD</service_code>
    <service_name>Mud &amp; Debris</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>Manhole</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>false</metadata>
    <service_code>MH</service_code>
    <service_name>Manhole</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>Oil Spillage</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>false</metadata>
    <service_code>OS</service_code>
    <service_name>Oil Spillage</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>Other</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>false</metadata>
    <service_code>OT</service_code>
    <service_name>Other</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>Pothole</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>false</metadata>
    <service_code>PO</service_code>
    <service_name>Pothole</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>Property Damage</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>false</metadata>
    <service_code>PD</service_code>
    <service_name>Property Damage</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>Road Marking</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>false</metadata>
    <service_code>RM</service_code>
    <service_name>Road Marking</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>Road traffic signs</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>false</metadata>
    <service_code>SN</service_code>
    <service_name>Road traffic signs</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>Traffic</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>false</metadata>
    <service_code>SP</service_code>
    <service_name>Traffic</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>Utilities</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>false</metadata>
    <service_code>UT</service_code>
    <service_name>Utilities</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>Vegetation</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>false</metadata>
    <service_code>VG</service_code>
    <service_name>Vegetation</service_name>
    <type>realtime</type>
  </service>
</services>
XML
    is $res->content, $expected
        or diag $res->content;
};

done_testing;

__END__
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
<service_request_updates>
</service_request_updates>
CONTENT

    my $update_0_xml = <<CONTENT;
<?xml version="1.0" encoding="utf-8"?>
<service_request_updates>
  <request_updates>
    <description>Fixed</description>
    <media_url></media_url>
    <service_request_id>0</service_request_id>
    <status>closed</status>
    <update_id>1</update_id>
    <updated_datetime>2014-01-01T13:00:00Z</updated_datetime>
  </request_updates>
</service_request_updates>
CONTENT

my $updates_xml = <<CONTENT;
<?xml version="1.0" encoding="utf-8"?>
<service_request_updates>
  <request_updates>
    <description>Fixed</description>
    <media_url></media_url>
    <service_request_id>0</service_request_id>
    <status>closed</status>
    <update_id>1</update_id>
    <updated_datetime>2014-01-01T13:00:00Z</updated_datetime>
  </request_updates>
  <request_updates>
    <description>Have investigated. Looks tricky!</description>
    <media_url></media_url>
    <service_request_id>1</service_request_id>
    <status>open</status>
    <update_id>2</update_id>
    <updated_datetime>2014-03-01T13:00:00Z</updated_datetime>
  </request_updates>
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
