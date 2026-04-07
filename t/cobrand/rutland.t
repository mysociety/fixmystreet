use CGI::Simple;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
my $mech = FixMyStreet::TestMech->new;

use Open311::PopulateServiceList;

# Create test data
my $user = $mech->create_user_ok( 'rutland@example.com' );
my $body = $mech->create_body_ok( 2600, 'Rutland County Council', { cobrand => 'rutland' });
my $staffuser = $mech->create_user_ok( 'staff@example.com', name => 'Staff', from_body => $body );
my $contact = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Other',
    email => 'LIGHT',
);
$contact->set_extra_metadata(
    group => 'Street Furniture',
);
$contact->update;

my $contact2 = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Bins',
    email => 'BINS',
);
$contact2->set_extra_metadata(
    group => 'Street Furniture',
);
$contact2->update;

my $confirm_contact = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Drains',
    email => 'Confirm-1234',
);

my $recategorisation_contact = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Street Cleansing',
    email => '1234',
);

my @reports = $mech->create_problems_for_body( 1, $body->id, 'Test', {
    cobrand => 'rutland',
    user => $user,
});
my $report = $reports[0];

for my $update ('in progress', 'unable to fix') {
    FixMyStreet::DB->resultset('Comment')->find_or_create( {
        problem_state => $update,
        problem_id => $report->id,
        user_id    => $user->id,
        name       => 'User',
        mark_fixed => 'f',
        text       => "This update marks it as $update",
        state      => 'confirmed',
        confirmed  => 'now()',
        anonymous  => 'f',
    } );
}

subtest 'testing special Open311 behaviour for SalesForce', sub {
    $report->set_extra_fields();
    $report->update;
    $body->update( { send_method => 'Open311', endpoint => 'http://rutland.endpoint.example.com', jurisdiction => 'FMS', api_key => 'test', send_comments => 1 } );
    FixMyStreet::override_config {
        STAGING_FLAGS => { send_reports => 1 },
        ALLOWED_COBRANDS => [ 'fixmystreet', 'rutland' ],
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
    is $c->param('attribute[title]'), $report->title, 'Request had title';
    is $c->param('attribute[description]'), $report->detail, 'Request had description';
    is $c->param('attribute[external_id]'), $report->id, 'Request had correct ID';
    is $c->param('jurisdiction_id'), 'FMS', 'Request had correct jurisdiction';
};

my ($confirm_problem) = $mech->create_problems_for_body( 1, $body->id, 'Test', {
    cobrand => 'rutland',
    user => $user,
    category => $confirm_contact->category,
});

subtest 'testing special Open311 behaviour for Confirm', sub {
    $body->update( { send_method => 'Open311', endpoint => 'http://rutland.endpoint.example.com', jurisdiction => 'FMS', api_key => 'test', send_comments => 1 } );
    FixMyStreet::override_config {
        STAGING_FLAGS => { send_reports => 1 },
        ALLOWED_COBRANDS => [ 'fixmystreet', 'rutland' ],
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
    is $c->param('attribute[title]'), $report->title, 'Request had title';
    is $c->param('attribute[description]'), $report->detail, 'Request had description';
    is $c->param('attribute[report_url]'), 'http://rutland.example.org/report/' . $confirm_problem->id, 'Request had report_url';
    is $c->param('jurisdiction_id'), 'FMS', 'Request had correct jurisdiction';
};

subtest 'check open311_contact_meta_override' => sub {
    my $processor = Open311::PopulateServiceList->new();

    my $meta_xml = '<?xml version="1.0" encoding="utf-8"?>
<service_definition>
    <service_code>100</service_code>
    <attributes>
        <attribute>
            <automated>server_set</automated>
            <code>notice</code>
            <datatype>string</datatype>
            <datatype_description></datatype_description>
            <description>&lt;p&gt;&lt;span&gt;This is the group HTML hint&lt;/span&gt;&lt;/p&gt;&lt;p&gt;&lt;span&gt;This is the category HTML hint&lt;/span&gt;&lt;/p&gt;</description>
            <order>2</order>
            <required>false</required>
            <variable>false</variable>
        </attribute>
    </attributes>
</service_definition>
    ';

    my $contact = FixMyStreet::DB->resultset('Contact')->create({
        body_id => $body->id,
        email => '100',
        category => 'Traffic Lights',
        state => 'confirmed',
        editor => $0,
        whenedited => \'current_timestamp',
        note => 'test contact',
    });

    my $o = Open311->new(
        jurisdiction => 'mysociety',
        endpoint => 'http://example.com',
    );
    Open311->_inject_response('/services/100.xml', $meta_xml);

    $processor->_current_open311( $o );
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'rutland' ],
    }, sub {
        $processor->_current_body( $body );
    };
    $processor->_current_service( { service_code => 100, service_name => 'Traffic Lights' } );
    $processor->_add_meta_to_contact( $contact );

    is scalar(@{ $contact->get_extra_fields }), 1, "One notice added to extra fields";
    my $notice = ${$contact->get_extra_fields}[0];
    is $notice->{description}, '<p><span>This is the group HTML hint</span></p><p><span>This is the category HTML hint</span></p>', 'Salesforce data added as notice';
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'rutland' ],
    MAPIT_URL        => 'http://mapit.uk/',
}, sub {
    $mech->log_in_ok($user->email);
    for my $test (
                  { category => 'Drains', length => 50 },
                  { category => 'Bins', length => 40 }
    ) {
        $mech->get('/report/new?longitude=-0.727877&latitude=52.670447');
        $mech->submit_form_ok({
          with_fields => {
                         category => $test->{category},
                         detail => "Report details",
                         title => "Test report",
                         name => "Testingauserwithaverylong Namethatgoesonforalotofcharacters",
         }
       });
       $mech->content_contains('Names are limited to ' . $test->{length} . ' characters', "Correct report validation used");
    }
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'rutland' ],
    MAPIT_URL        => 'http://mapit.uk/',
    STAGING_FLAGS => { send_reports => 1 },
}, sub {
    my ($report, $report2) = $mech->create_problems_for_body(2, $body->id, 'Hedge hanging over road', {
          cobrand => 'rutland',
          category => 'Drains',
          whensent => DateTime->now,
    });

    subtest 'Report sent to Confirm redirected to Salesforce' => sub {
        FixMyStreet::Script::Reports::send();
        $report->update({ external_id => 12345 });
        $report2->update({ external_id => 34567 });

        my $requests_xml = qq{<?xml version="1.0" encoding="utf-8"?>
                <service_requests_updates>
                <request_update>
                <update_id>UPDATE_1</update_id>
                <service_request_id>12345</service_request_id>
                <status>OPEN</status>
                <external_status_code>1600</external_status_code>
                <updated_datetime>UPDATED_DATETIME</updated_datetime>
                </request_update>
                <request_update>
                <update_id>UPDATE_2</update_id>
                <service_request_id>34567</service_request_id>
                <status>OPEN</status>
                <external_status_code>1601</external_status_code>
                <updated_datetime>UPDATED_DATETIME</updated_datetime>
                </request_update>
                </service_requests_updates>
            };
        my $update_dt = DateTime->now(formatter => DateTime::Format::W3CDTF->new);
        $requests_xml =~ s/UPDATED_DATETIME/$update_dt/g;

        my $o = Open311->new( jurisdiction => 'FMS', endpoint => 'http://rutland.endpoint.example.com', extended_statuses => 1);
        Open311->_inject_response('/servicerequestupdates.xml', $requests_xml);

        my $update = Open311::GetServiceRequestUpdates->new(
              system_user => $staffuser,
              current_open311 => $o,
              current_body => $body,
              blank_updates_permitted => 1,
        );

        $update->process_body;
        $report->discard_changes;
        $report2->discard_changes;

        is $report->comments->count, 1;
        is $report->comments->next->state, 'hidden';
        is $report->category, 'Street Cleansing', 'Category changed';
        is $report2->category, 'Drains', 'Category remains the same';

        FixMyStreet::Script::Reports::send();
        $report->discard_changes;
        $report2->discard_changes;

        is $report->external_id, 248, 'External ID updated after resend';
        is $report2->external_id, 34567, 'External ID remains with Confirm';

        $report->discard_changes;
        is $report->comments->count, 1, 'No additional comments added';
    };
};

done_testing();
