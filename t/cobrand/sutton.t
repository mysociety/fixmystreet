use Test::MockModule;
use FixMyStreet::TestMech;
use FixMyStreet::SendReport::Open311;
my $mech = FixMyStreet::TestMech->new;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

# Mock fetching bank holidays
my $uk = Test::MockModule->new('FixMyStreet::Cobrand::UK');
$uk->mock('_fetch_url', sub { '{}' });

# Create test data
my $user = $mech->create_user_ok( 'sutton@example.com', name => 'Sutton' );
my $body = $mech->create_body_ok( 2482, 'Sutton Council', {
    can_be_devolved => 1, send_extended_statuses => 1, comment_user => $user,
    send_method => 'Open311', endpoint => 'http://endpoint.example.com', jurisdiction => 'FMS', api_key => 'test', send_comments => 1
}, {
    cobrand => 'sutton'
});

$mech->create_contact_ok(
    body => $body,
    category => 'Report missed collection',
    email => 'missed',
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
    ALLOWED_COBRANDS => 'sutton',
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
};

done_testing();
