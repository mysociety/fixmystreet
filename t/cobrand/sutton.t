use CGI::Simple;
use Test::MockModule;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use FixMyStreet::SendReport::Open311;
my $mech = FixMyStreet::TestMech->new;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

# Mock fetching bank holidays
my $uk = Test::MockModule->new('FixMyStreet::Cobrand::UK');
$uk->mock('_fetch_url', sub { '{}' });

# Create test data
my $user = $mech->create_user_ok( 'sutton@example.com', name => 'Sutton Council' );
my $body = $mech->create_body_ok( 2498, 'Sutton Council', {
    can_be_devolved => 1, send_extended_statuses => 1, comment_user => $user,
    send_method => 'Open311', endpoint => 'http://endpoint.example.com', jurisdiction => 'FMS', api_key => 'test', send_comments => 1
}, {
    cobrand => 'sutton'
});

$mech->create_contact_ok(
    body => $body,
    category => 'Graffiti',
    email => 'graffiti@example.org',
    send_method => 'Email',
);
$mech->create_contact_ok(
    body => $body,
    category => 'Report missed collection',
    email => 'missed',
    send_method => 'Open311',
    endpoint => 'waste-endpoint',
    extra => { type => 'waste' },
    group => ['Waste'],
);
$mech->create_contact_ok(
    body => $body,
    category => 'Garden Subscription',
    email => '1638',
    send_method => 'Open311',
    endpoint => 'waste-endpoint',
    extra => { type => 'waste' },
    group => ['Waste'],
);

my @reports = $mech->create_problems_for_body( 1, $body->id, 'Test', {
    latitude => 51.402096,
    longitude => 0.015784,
    category => 'Report missed collection',
    cobrand => 'sutton',
    areas => '2498',
    user => $user,
    send_method_used => 'Open311',
});
my $report = $reports[0];

FixMyStreet::override_config {
    ALLOWED_COBRANDS => ['sutton', 'fixmystreet'],
    MAPIT_URL => 'http://mapit.uk/',
    STAGING_FLAGS => { send_reports => 1 },
}, sub {
    subtest 'test waste duplicate' => sub {
        my $sender = FixMyStreet::SendReport::Open311->new(
            bodies => [ $body ], body_config => { $body->id => $body },
        );
        Open311->_inject_response('/requests.xml', '<?xml version="1.0" encoding="utf-8"?><errors><error><code></code><description>Missed Collection event already open for the property</description></error></errors>', 500);
        $sender->send($report, {
            easting => 1,
            northing => 2,
            url => 'http://example.org/',
        });
        is $report->state, 'duplicate', 'State updated';
    };

    subtest 'test DD taking so long it expires' => sub {
        my $sender = FixMyStreet::SendReport::Open311->new(
            bodies => [ $body ], body_config => { $body->id => $body },
        );
        my $title = $report->title;
        $report->update({ title => "Garden Subscription - Renew" });
        Open311->_inject_response('/requests.xml', '<?xml version="1.0" encoding="utf-8"?><errors><error><code></code><description>Cannot renew this property, a new request is required</description></error></errors>', 500);
        $sender->send($report, {
            easting => 1,
            northing => 2,
            url => 'http://example.org/',
        });
        is $report->get_extra_field_value("Request_Type"), 1, 'Type updated';
        is $report->title, "Garden Subscription - New";
        $report->update({ title => $title });
    };

    subtest 'test duplicate event at the Echo side' => sub {
        my $sender = FixMyStreet::SendReport::Open311->new(
            bodies => [ $body ], body_config => { $body->id => $body },
        );
        my $echo = Test::MockModule->new('Integrations::Echo');
        $echo->mock('GetEvent', sub { {
            Guid => 'a-guid',
            Id => 123,
        } } );
        Open311->_inject_response('/requests.xml', '<?xml version="1.0" encoding="utf-8"?><errors><error><code></code><description>Duplicate Event! Original eventID: 123</description></error></errors>', 500);
        $sender->send($report, {
            easting => 1,
            northing => 2,
            url => 'http://example.org/',
        });
        is $sender->success, 1;
        is $report->external_id, 'a-guid';
    };

    subtest 'correct payment data sent across' => sub {
        $report->category('Garden Subscription');
        $report->update_extra_field({ name => 'PaymentCode', value => 'Code4321' });
        $report->update_extra_field({ name => 'payment', value => '8300' });
        $report->state('confirmed');
        $report->update;
        FixMyStreet::Script::Reports::send();
        $report->discard_changes;
        my $req = Open311->test_req_used;
        my $c = CGI::Simple->new($req->content);
        is $c->param('attribute[Transaction_Number]'), 'Code4321';
        is $c->param('attribute[Payment_Amount]'), '83.00';
    };

    subtest '.com reports do not get branding/broken link' => sub {
        ok $mech->host("www.fixmystreet.com"), "change host to www";
        $mech->clear_emails_ok;
        $mech->log_in_ok($user->email);
        $mech->get_ok('/report/new?latitude=51.354679&longitude=-0.183895');
        $mech->submit_form_ok({
            with_fields => {
                title => "Test graffiti",
                detail => 'Test graffiti details.',
                category => 'Graffiti',
            }
        }, "submit details");
        $mech->content_contains('Thank you for reporting');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        my $id = $report->id;
        ok $report, "Found the report";
        is $report->title, 'Test graffiti', 'Got the correct report';
        is $report->bodies_str, $body->id, 'Report was sent to parish';
        FixMyStreet::Script::Reports::send();
        my $email = $mech->get_email;
        my $body = $mech->get_text_body_from_email($email);
        like $body, qr/Dear Sutton Council,\s+A user of FixMyStreet has submitted/;
        like $body, qr{http://www.example.org/report/$id};
    };

};

done_testing();
