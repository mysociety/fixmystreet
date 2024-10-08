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
}, {
    cobrand => 'greenwich',
});

my $contact = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Pothole',
    email => 'HOLE',
);
my $contact_old = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Something Old',
    email => 'OLD',
    endpoint => 'https://open311.royalgreenwich.gov.uk/',
);

my $user = $mech->create_user_ok( 'greenwich@example.com' );
my @reports = $mech->create_problems_for_body( 1, $body->id, 'Test', {
    category => 'Pothole',
    cobrand => 'greenwich',
    user => $user,
});
my $report = $reports[0];
$report->geocode({
    display_name => 'Constitution Hill, London',
    address => {
        road => 'Constitution Hill',
        city => 'London',
    },
});
$report->update;


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
    );
    Open311->_inject_response('/services/HOLE.xml', $meta_xml);

    $processor->_current_open311( $o );
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'greenwich' ],
    }, sub {
        $processor->_current_body( $body );
    };
    $processor->_current_service( { service_code => 'HOLE' } );
    $processor->_add_meta_to_contact( $contact );
    $contact->update;

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

    is_deeply $contact->get_extra_fields, $extra, 'Easting has automated set';
};

subtest 'testing special Open311 behaviour', sub {
    FixMyStreet::override_config {
        STAGING_FLAGS => { send_reports => 1 },
        ALLOWED_COBRANDS => [ 'greenwich' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        FixMyStreet::Script::Reports::send();
    };
    $report->discard_changes;
    ok $report->whensent, 'Report marked as sent';
    is $report->send_method_used, 'Open311', 'Report sent via Open311';
    is $report->external_id, 248, 'Report has right external ID';

    my $req = Open311->test_req_used;
    my $c = CGI::Simple->new($req->content);
    is $c->param('attribute[external_id]'), $report->id, 'Request had correct ID';
    is $c->param('attribute[easting]'), 529025, 'Request had correct easting';
    is $c->param('attribute[closest_address]'), 'Constitution Hill, London', 'Request had correct closest address';
};

subtest 'Old server cutoff' => sub {
    my ($report1) = $mech->create_problems_for_body(1, $body->id, 'Test Problem 1', { category => 'Pothole' });
    my ($report2) = $mech->create_problems_for_body(1, $body->id, 'Test Problem 2', { category => 'Something Old' });
    my $update1 = $mech->create_comment_for_problem($report1, $user, 'Anonymous User', 'Update text', 't', 'confirmed', undef);
    my $update2 = $mech->create_comment_for_problem($report2, $user, 'Anonymous User', 'Update text', 't', 'confirmed', undef);
    my $cobrand = FixMyStreet::Cobrand::Greenwich->new;
    is $cobrand->should_skip_sending_update($update1), 0;
    is $cobrand->should_skip_sending_update($update2), 1;
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
