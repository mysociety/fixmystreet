use CGI::Simple;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use Open311::PopulateServiceList;

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok( 2493, 'Royal Borough of Greenwich', {
    send_method => 'Open311',
    endpoint => 'endpoint',
    api_key => 'key',
    jurisdiction => 'greenwich',
});

my $contact = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Pothole',
    email => 'HOLE',
);

my $user = $mech->create_user_ok( 'greenwich@example.com' );
my @reports = $mech->create_problems_for_body( 1, $body->id, 'Test', {
    category => 'Pothole',
    cobrand => 'greenwich',
    user => $user,
});
my $report = $reports[0];

subtest 'check services override' => sub {
    my $processor = Open311::PopulateServiceList->new();

    my $meta_xml = '<?xml version="1.0" encoding="utf-8"?>
<service_definition>
    <service_code>HOLE</service_code>
    <attributes>
        <attribute>
            <variable>true</variable>
            <code>easting</code>
            <datatype>string</datatype>
            <required>true</required>
            <order>1</order>
            <description>Easting</description>
        </attribute>
        <attribute>
            <variable>true</variable>
            <code>size</code>
            <datatype>string</datatype>
            <required>true</required>
            <order>2</order>
            <description>How big is the pothole</description>
        </attribute>
    </attributes>
</service_definition>
    ';

    my $o = Open311->new(
        jurisdiction => 'mysociety',
        endpoint => 'http://example.com',
        test_mode => 1,
        test_get_returns => { 'services/HOLE.xml' => $meta_xml }
    );

    $processor->_current_open311( $o );
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'greenwich' ],
    }, sub {
        $processor->_current_body( $body );
    };
    $processor->_current_service( { service_code => 'HOLE' } );
    $processor->_add_meta_to_contact( $contact );

    my $extra = [ {
        automated => 'server_set',
        variable => 'true',
        code => 'easting',
        datatype => 'string',
        required => 'true',
        order => 1,
        description => 'Easting',
    }, {
        variable => 'true',
        code => 'size',
        datatype => 'string',
        required => 'true',
        order => 2,
        description => 'How big is the pothole',
    } ];

    $contact->discard_changes;
    is_deeply $contact->get_extra_fields, $extra, 'Easting has automated set';
};

subtest 'testing special Open311 behaviour', sub {
    my $test_data;
    FixMyStreet::override_config {
        STAGING_FLAGS => { send_reports => 1 },
        ALLOWED_COBRANDS => [ 'greenwich' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $test_data = FixMyStreet::Script::Reports::send();
    };
    $report->discard_changes;
    ok $report->whensent, 'Report marked as sent';
    is $report->send_method_used, 'Open311', 'Report sent via Open311';
    is $report->external_id, 248, 'Report has right external ID';

    my $req = $test_data->{test_req_used};
    my $c = CGI::Simple->new($req->content);
    is $c->param('attribute[external_id]'), $report->id, 'Request had correct ID';
    is $c->param('attribute[easting]'), 529025, 'Request had correct easting';
};

subtest 'RSS feed on .com' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'fixmystreet',
        MAPIT_TYPES => ['GRE'],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->get_ok('/rss/reports/Greenwich');
        is $mech->uri->path, '/rss/reports/Greenwich';
    };
};

subtest 'RSS feed on Greenwich' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'greenwich',
        MAPIT_TYPES => ['GRE'],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->get_ok('/rss/reports/Greenwich');
        is $mech->uri->path, '/rss/reports/Greenwich';
    };
};

done_testing();
