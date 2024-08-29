use Test::MockModule;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use File::Temp 'tempdir';

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech = FixMyStreet::TestMech->new;

# Mock tilma so TfL's report_new_is_on_tlrn method doesn't make a live API call.
use t::Mock::Tilma;
my $tilma = t::Mock::Tilma->new;
LWP::Protocol::PSGI->register($tilma->to_psgi_app, host => 'tilma.mysociety.org');

use constant CAMDEN_MAPIT_ID => 2505;
use constant BARNET_MAPIT_ID => 2489;

my $comment_user = $mech->create_user_ok('camden@example.net');
my $camden = $mech->create_body_ok(CAMDEN_MAPIT_ID, 'Camden Borough Council', {
    comment_user => $comment_user,
}, {
    cobrand => 'camden'
});

$mech->create_contact_ok(body_id => $camden->id, category => 'Potholes', email => 'potholes@camden.fixmystreet.com');
my $staffuser = $mech->create_user_ok( 'staff@example.com', name => 'Staffer', from_body => $camden );
$staffuser->user_body_permissions->create( { body => $camden, permission_type => 'report_edit' } );

$mech->create_contact_ok(
    body_id => $camden->id,
    category => 'Abandoned yellow bike',
    email => 'yellowbikes@example.org',
    send_method => 'Email',
    group => 'Hired e-bike or e-scooter',
);

$mech->create_contact_ok(
    body_id => $camden->id,
    category => 'Tree',
    email => 'ConfirmTrees-trees',
);

my $UPLOAD_DIR = tempdir( CLEANUP => 1 );
FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'camden', 'tfl' ],
    MAPIT_URL => 'http://mapit.uk/',
    PHOTO_STORAGE_OPTIONS => { UPLOAD_DIR => $UPLOAD_DIR },
}, sub {
    subtest "hides the TfL River Piers category" => sub {

        my $tfl = $mech->create_body_ok(CAMDEN_MAPIT_ID, 'TfL');
        $mech->create_contact_ok(body_id => $tfl->id, category => 'River Piers', email => 'tfl@example.org');
        $mech->create_contact_ok(body_id => $tfl->id, category => 'River Piers - Cleaning', email => 'tfl@example.org');
        $mech->create_contact_ok(body_id => $tfl->id, category => 'River Piers Damage doors and glass', email => 'tfl@example.org');

        ok $mech->host('camden.fixmystreet.com'), 'set host';

        my $json = $mech->get_ok_json('/report/new/ajax?latitude=51.529432&longitude=-0.124514');
        is_deeply [sort keys %{$json->{by_category}}], ['Abandoned yellow bike', 'Potholes', 'Tree'], "Camden doesn't have River Piers category";
    };

    subtest "show my name publicly checkbox doesn't appear on Camden's cobrand" => sub {
        $mech->get_ok('/report/new?latitude=51.529432&longitude=-0.124514');
        $mech->submit_form_ok({
            with_fields => {
                title => "Test report",
                detail => 'This is a test report',
                category => 'Potholes',
            }
        }, "submit details");
        $mech->content_lacks('Show my name publicly');
        $mech->content_lacks('may_show_name');

        # Now submit the form
        $mech->submit_form_ok({
            button => 'submit_register',
            with_fields => {
                title => "Test report",
                detail => 'This is a test report',
                photo1 => '',
                category => 'Potholes',
                name => 'Test User',
                username_register => 'test@example.org',
                password_register => 'secretsecret',
            }
        });

        # Get the latest report
        my $report = FixMyStreet::DB->resultset('Problem')->order_by('-id')->first;
        ok $report, 'found report';

        # Check the user is not shown
        is $report->anonymous, 1, 'report is anonymous';
    };

    subtest "updates page doesn't have the show my name publicly checkbox" => sub {
        my ($report) = $mech->create_problems_for_body(1, $camden->id, {
            anonymous => 0,
            cobrand => 'camden',
            name => 'Test User',
        });

        $mech->get_ok('/report/' . $report->id);
        $mech->content_lacks('Show my name publicly');
        $mech->content_lacks('may_show_name');
        $mech->content_lacks('Test User', "still don't show the name");
    };

    subtest "updates that aren't anonymous still don't show the name" => sub {
        my ($report) = $mech->create_problems_for_body(1, $camden->id, {
            anonymous => 0,
            cobrand => 'camden',
            name => 'Test User',
        });

        $mech->create_comment_for_problem($report, $report->user, 'Test User', 'This is a test comment', 0, 'confirmed', 'confirmed');

        $mech->get_ok('/report/' . $report->id);
        $mech->content_contains('This is a test comment');
        $mech->content_lacks('Test User');
    };

    subtest 'Dashboard CSV extra columns' => sub {
        $mech->log_in_ok($staffuser->email);
        $mech->get_ok('/dashboard?export=1');
        $mech->content_contains('"Reported As","User Name","User Email"');
        $mech->content_like(qr/default,,"Test User",pkg-tcobrandcamdent-test\@example.com/);
    };

    subtest "bike reports automatically closed" => sub {
        $mech->clear_emails_ok;

        my ($p) = $mech->create_problems_for_body(1, $camden->id, 'Title', {
            cobrand => 'camden',
            category => 'Abandoned yellow bike',
            areas => ',2505,', # So admin categories_for_point can get Camden results
        } );

        FixMyStreet::Script::Reports::send();

        $p->discard_changes;
        ok $p->whensent, 'Report marked as sent';
        is $p->get_extra_metadata('sent_to')->[0], 'yellowbikes@example.org', 'sent_to extra metadata set';
        is $p->state, 'closed', 'report closed having sent email';
        is $p->comments->count, 1, 'comment added';
        like $p->comments->first->text, qr/This has been forwarded to/, 'correct comment text';

        $mech->email_count_is(1);
    };

    subtest 're-categorising auto-resends' => sub {
        my $report = FixMyStreet::DB->resultset('Problem')->order_by('-id')->first;
        is $report->send_state, 'sent';
        $mech->get_ok('/admin/report_edit/' . $report->id);
        $mech->submit_form_ok({ with_fields => { category => 'Tree' } });
        $report->discard_changes;
        is $report->send_state, 'unprocessed';
        $report->update({ send_state => 'sent' });
        $mech->submit_form_ok({ with_fields => { category => 'Potholes' } });
        $report->discard_changes;
        is $report->send_state, 'unprocessed';
    };
};

    my $barnet = $mech->create_body_ok(BARNET_MAPIT_ID, 'Barnet Borough Council');
    my $tfl = FixMyStreet::DB->resultset('Body')->search({ name => 'TfL'})->first;
    $mech->create_contact_ok(body_id => $tfl->id, category => 'Bus stops', email => 'tfl@example.org');

    FixMyStreet::DB->resultset('BodyArea')->find_or_create({ area_id => BARNET_MAPIT_ID, body_id => $tfl->id }); # TfL covers Barnet, already set to cover Camden
    FixMyStreet::DB->resultset('BodyArea')->find_or_create({ area_id => BARNET_MAPIT_ID, body_id => $camden->id }); # Camden covers Barnet
    FixMyStreet::DB->resultset('BodyArea')->find_or_create({ area_id => CAMDEN_MAPIT_ID, body_id => $barnet->id }); # Barnet covers Camden

    $mech->create_contact_ok(
        body_id => $barnet->id,
        category => 'Flytipping',
        email => 'barnetflytipping@example.org',
        send_method => 'Email'
    );

for my $test (
    {
        description =>  'reporting in Camden area, not on boundary asset',
        result => 'shows only Camden and TfL categories',
        asset_returned => undef,
        location => '/report/new/ajax?latitude=51.529432&longitude=-0.124514',
        categories => ['Abandoned yellow bike', 'Bus stops', 'Potholes', 'River Piers', 'River Piers - Cleaning', 'River Piers Damage doors and glass', 'Tree'],
    },
    {
        description =>  'reporting in Camden area, on boundary asset labelled Camden',
        result => 'shows only Camden and TfL categories',
        asset_returned => 'LB Camden',
        location => '/report/new/ajax?latitude=51.529432&longitude=-0.124514',
        categories => ['Abandoned yellow bike', 'Bus stops', 'Potholes', 'River Piers', 'River Piers - Cleaning', 'River Piers Damage doors and glass', 'Tree'],
    },
    {
        description =>  'reporting in Camden area, on boundary asset labelled Barnet',
        result => 'shows only Barnet and TfL categories',
        asset_returned => 'LB Barnet',
        location => '/report/new/ajax?latitude=51.529432&longitude=-0.124514',
        categories => [ 'Bus stops', 'Flytipping', 'River Piers', 'River Piers - Cleaning', 'River Piers Damage doors and glass'],
    },
    {
        description =>  'reporting in Barnet area, not on boundary asset',
        result => 'not Camden\'s responsibility',
        asset_returned => undef,
        location => '/report/new/ajax?latitude=51.558568&longitude=-0.207702',
        barnet_categories => [ 'Bus stops', 'Flytipping', 'River Piers', 'River Piers - Cleaning', 'River Piers Damage doors and glass']
    },
    {
        description =>  'reporting in Barnet area, on asset labelled Barnet',
        result => 'shows only Barnet and TfL categories',
        asset_returned => ['LB Barnet'],
        location => '/report/new/ajax?latitude=51.558568&longitude=-0.207702',
        categories => [ 'Bus stops', 'Flytipping', 'River Piers', 'River Piers - Cleaning', 'River Piers Damage doors and glass'],
    })
{
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'tfl', 'camden', 'fixmystreet' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        my $camden_mock = Test::MockModule->new('FixMyStreet::Cobrand::Camden');
        for my $host ('fixmystreet.com', 'camden.fixmystreet.com') {
            $mech->host($host);
            if ($host =~ /camden/ && $test->{categories} ) {
                    @{$test->{categories}} = grep { $_ !~ /River Piers/ } @{$test->{categories}};
            }
            subtest $test->{description} => sub {
                $camden_mock->mock('check_report_is_on_cobrand_asset', sub { $test->{asset_returned} });
                my $json = $mech->get_ok_json($test->{location});
                if ($test->{categories}) {
                    is_deeply [sort keys %{$json->{by_category}}], $test->{categories}, $host . ': ' . $test->{result};
                } else {
                    if ($host =~ /camden/) {
                        $mech->content_contains('That location is not covered by Camden Council', 'camden.fixmystreet.com: can\'t make Barnet report');
                    } else {
                        is_deeply [sort keys %{$json->{by_category}}], $test->{barnet_categories}, 'fixmystreet.com: making report in Barnet';
                    }
                }
            };
        }
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'camden', 'tfl' ],
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    subtest 'Make a report to Barnet from Camden' => sub {
        $mech->host('camden.fixmystreet.com');
        my $camden_mock = Test::MockModule->new('FixMyStreet::Cobrand::Camden');
        $camden_mock->mock('check_report_is_on_cobrand_asset', sub { 'LB Barnet' });
        $mech->get_ok('/report/new?latitude=51.529432&longitude=-0.124514');
        $mech->submit_form_ok({ with_fields => {
            title => 'Report for Barnet',
            detail => 'Test report details.',
            category => 'Flytipping',
            name => 'Gavin Stacey',
        } }, "submit report");
        $mech->content_like(qr/passed this report on to.*<b>Barnet Borough Council<\/b>/s);
    }
};

done_testing;
