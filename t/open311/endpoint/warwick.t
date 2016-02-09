use strict; use warnings;

use Test::More;
use Test::LongString;
use Test::MockTime ':all';

use Data::Dumper;
use JSON::MaybeXS;

use FixMyStreet::DB;

use Module::Loaded;
BEGIN { mark_as_loaded('DBD::Oracle') }

use t::open311::endpoint::Endpoint_Warwick;

use LWP::Protocol::PSGI;
use Open311::PopulateServiceList;
use Open311::GetServiceRequestUpdates;

my $endpoint = t::open311::endpoint::Endpoint_Warwick->new;

subtest "GET Service List" => sub {
    my $res = $endpoint->run_test_request( GET => '/services.xml' );
    ok $res->is_success, 'xml success';
    my $expected = <<XML;
<?xml version="1.0" encoding="utf-8"?>
<services>
  <service>
    <description>Pothole</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>true</metadata>
    <service_code>PO</service_code>
    <service_name>Pothole</service_name>
    <type>realtime</type>
  </service>
</services>
XML
    is $res->content, $expected
        or diag $res->content;
};

subtest "POST OK" => sub {
    set_fixed_time('2014-01-01T12:00:00Z');
    my $res = $endpoint->run_test_request( 
        POST => '/requests.json', 
        api_key => 'test',
        service_code => 'PO',
        address_string => '22 Acacia Avenue',
        first_name => 'Bob',
        last_name => 'Mould',
        'attribute[easting]' => 100,
        'attribute[northing]' => 100,
        'attribute[external_id]' => 1001,
        'attribute[closest_address]' => '22 Acacia Avenue',
    );
    ok $res->is_success, 'valid request'
        or diag $res->content;

    is_deeply decode_json($res->content),
        [ {
            "service_notice" => "Warwickshire Open311 Endpoint",
            "service_request_id" => 1001
        } ], 'correct json returned';

    is_deeply \%t::open311::endpoint::Endpoint_Warwick::BINDINGS, 
        {
          ':ce_surname' => 'MOULD',
          ':ce_y' => '100',
          ':ce_x' => '100',
          ':ce_work_phone' => '',
          ':ce_contact_type' => 'PU',
          ':ce_source' => 'FMS',
          ':ce_doc_reference' => '1001',
          ':ce_enquiry_type' => 'PO',
          ':ce_email' => '',
          ':ce_description' => '',
          ':ce_location' => '22 Acacia Avenue',
          ':ce_incident_datetime' => '2014-01-01 12:00',
          ':ce_class' => 'N/A',
          ':ce_cpr_id' => 5,
          ':ce_compl_user_type' => 'USER',
          ':ce_status_code' => 'RE',
          ':ce_cat' => 'DEF',
          ':ce_forename' => 'BOB'
        }, 
        'bindings as expected';
};

subtest 'updates' => sub {
    my $res = $endpoint->run_test_request( GET => '/servicerequestupdates.xml', );
    ok $res->is_success, 'valid request' or diag $res->content;

my $expected = <<XML;
<?xml version="1.0" encoding="utf-8"?>
<service_request_updates>
  <request_update>
    <description>Closed the ticket</description>
    <media_url></media_url>
    <service_request_id>1001</service_request_id>
    <status>closed</status>
    <update_id>999</update_id>
    <updated_datetime>2014-07-23T11:07:00+01:00</updated_datetime>
  </request_update>
</service_request_updates>
XML

    is_string $res->content, $expected, 'xml string ok'
    or diag $res->content;

    chomp (my $expected_sql = <<SQL);
SELECT * FROM (
        SELECT
            row_id,
            service_request_id,
            to_char(updated_timedate, 'YYYY-MM-DD HH24:MI'),
            status,
            description
        FROM higatlas.fms_update
        WHERE updated_timedate >= to_date(2013-12-31 12:00, YYYY-MM-DD HH24:MI) AND (status='OPEN' OR status='CLOSED')
        ORDER BY updated_timedate DESC) WHERE ROWNUM <= 1000
SQL

    is_string $t::open311::endpoint::Endpoint_Warwick::UPDATES_SQL, $expected_sql, 'SQL as expected';
};

subtest "End to end" => sub {

    # We create and instance of the endpoint as a PSGI app
    # And then bind it to the dummy URL.  This mocks that whole hostname, so that FMS's
    # calls via Open311.pm are rerouted to our PSGI app.
    # (This saves us all the faff of having to launch and manage a new server process
    # for this test)

    my $endpoint_psgi = t::open311::endpoint::Endpoint_Warwick->run_if_script;

    my $ENDPOINT = 'open311.warwickshire.gov.uk';
    LWP::Protocol::PSGI->register($endpoint_psgi, host => $ENDPOINT);

    my $WARWICKSHIRE_MAPIT_ID = 2243;

    my $db = FixMyStreet::DB->connect;

    $db->txn_begin;

    my $body = FixMyStreet::DB->resultset('Body')->find_or_create( {
        id => $WARWICKSHIRE_MAPIT_ID,
        name => 'Warwickshire County Council',
    });

    my $user = FixMyStreet::DB->resultset('User')
        ->find_or_create( { email => 'test@example.com', name => 'Test User' } );

    $body->update({
        jurisdiction => 'wcc',
        endpoint => "http://$ENDPOINT",
        api_key => 'SEEKRIT',
        send_method => 'Open311',
        send_comments => 1,
        comment_user_id => $user->id,
    });

    $body->body_areas->find_or_create({
        area_id => $WARWICKSHIRE_MAPIT_ID
    } );

    subtest "Populate service list" => sub {
        # as per bin/open311-populate-service-list

        $body->contacts->delete;

        is $body->contacts->count, 0, 'sanity check';

        my $bodies = self_rs($body);

        my $p = Open311::PopulateServiceList->new( bodies => $bodies, verbose => 0, schema => $db );
        $p->process_bodies;

        is $body->contacts->count, 1, 'Categories imported from Open311';
    };

    set_fixed_time('2014-07-20T15:05:00Z');

    my $problem = FixMyStreet::DB->resultset('Problem')->create({
        postcode           => 'WC1 1AA',
        bodies_str         => $WARWICKSHIRE_MAPIT_ID,
        areas              => ",$WARWICKSHIRE_MAPIT_ID,",
        category           => 'Pothole',
        title              => 'Testing',
        detail             => 'Testing Detail',
        used_map           => 1,
        name               => 'Joe Bloggs',
        anonymous          => 0,
        state              => 'confirmed',
        confirmed          => '2014-07-20 15:00:00',
        lastupdate         => '2014-07-20 15:00:00',
        lang               => 'en-gb',
        service            => '',
        cobrand            => 'fixmystreet', # e.g. UK
        cobrand_data       => '',
        send_questionnaire => 0,
        latitude           => '52.2804',
        longitude          => '-1.5897',
        user_id            => $user->id,
    });

    subtest "Send report" => sub {
        # as per bin/send-reports

        FixMyStreet::override_config { 
            ALLOWED_COBRANDS => [ 'fixmystreet' ],
            SEND_REPORTS_ON_STAGING => 1,
            MAPIT_URL => 'http://mapit.mysociety.org/',
        }, sub {
            ## we can't (yet) just do following due to
            ## https://github.com/mysociety/fixmystreet/issues/893
            # self_rs($problem)->send_reports;

            ## instead, as we are in a transaction, we'll just delete everything else.
            my $rs = FixMyStreet::DB->resultset('Problem');
            $rs->search({ id => { '!=', $problem->id } })->delete;
            $rs->send_reports;
        };
        $problem->discard_changes;

        # Our test endpoint returns a hardcoded external ID.
        ok $problem->whensent, 'whensent has been set';
        is $problem->external_id, 1001, 'External ID set correctly'
            or die;
    };

    subtest "Send update" => sub {
        # as per bin/send-reports

        $problem->update({ lastupdate => '2014-07-20 15:05:00' }); # override

        set_fixed_time('2014-07-23T11:07:00Z');

        is $problem->comments->count, 0, 'sanity check update count';
        is $problem->state, 'confirmed', 'sanity check status';


        my $updates = Open311::GetServiceRequestUpdates->new( verbose => 1, schema => $db );
        $updates->fetch;

        $problem->discard_changes;
        is $problem->comments->count, 1, 'comment has been added';


        my $update = $problem->comments->single;
        is $update->user_id, $user->id, 'update user correct';
        is $update->state, 'confirmed', 'update itself is confirmed';

        is $update->problem_state, 'fixed - council', 'update marked problem as closed';
        is $problem->state, 'fixed - council', 'has been closed';
    };

    $db->txn_rollback;
};

restore_time();
done_testing;

sub self_rs {
    my ($row) = @_;
    # create a result-set with just this body (see also DBIx::Class::Helper::Row::SelfResultSet)
    return $row->result_source->resultset->search( $row->ident_condition );
}

__END__
  <service>
    <description>Bridges</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>true</metadata>
    <service_code>BR</service_code>
    <service_name>Bridges</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>Carriageway Defect</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>true</metadata>
    <service_code>CD</service_code>
    <service_name>Carriageway Defect</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>Roads/Highways</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>true</metadata>
    <service_code>CD</service_code>
    <service_name>Roads/Highways</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>Drainage</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>true</metadata>
    <service_code>DR</service_code>
    <service_name>Drainage</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>Debris/Spillage</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>true</metadata>
    <service_code>DS</service_code>
    <service_name>Debris/Spillage</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>Fences</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>true</metadata>
    <service_code>FE</service_code>
    <service_name>Fences</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>Pavements</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>true</metadata>
    <service_code>F D</service_code>
    <service_name>Pavements</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>Gully &amp; Catchpits</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>true</metadata>
    <service_code>GC</service_code>
    <service_name>Gully &amp; Catchpits</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>Ice/Snow</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>true</metadata>
    <service_code>IS</service_code>
    <service_name>Ice/Snow</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>Mud &amp; Debris</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>true</metadata>
    <service_code>MD</service_code>
    <service_name>Mud &amp; Debris</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>Manhole</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>true</metadata>
    <service_code>MH</service_code>
    <service_name>Manhole</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>Oil Spillage</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>true</metadata>
    <service_code>OS</service_code>
    <service_name>Oil Spillage</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>Other</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>true</metadata>
    <service_code>OT</service_code>
    <service_name>Other</service_name>
    <type>realtime</type>
  </service>

  <service>
    <description>Property Damage</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>true</metadata>
    <service_code>PD</service_code>
    <service_name>Property Damage</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>Road Marking</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>true</metadata>
    <service_code>RM</service_code>
    <service_name>Road Marking</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>Road traffic signs</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>true</metadata>
    <service_code>SN</service_code>
    <service_name>Road traffic signs</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>Traffic</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>true</metadata>
    <service_code>SP</service_code>
    <service_name>Traffic</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>Utilities</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>true</metadata>
    <service_code>UT</service_code>
    <service_name>Utilities</service_name>
    <type>realtime</type>
  </service>
  <service>
    <description>Vegetation</description>
    <group>highways</group>
    <keywords></keywords>
    <metadata>true</metadata>
    <service_code>VG</service_code>
    <service_name>Vegetation</service_name>
    <type>realtime</type>
  </service>
