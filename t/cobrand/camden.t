use Test::MockModule;
use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

# Mock tilma so TfL's report_new_is_on_tlrn method doesn't make a live API call.
use t::Mock::Tilma;
my $tilma = t::Mock::Tilma->new;
LWP::Protocol::PSGI->register($tilma->to_psgi_app, host => 'tilma.mysociety.org');

use constant CAMDEN_MAPIT_ID => 2505;

my $camden = $mech->create_body_ok(CAMDEN_MAPIT_ID, 'Camden Council', {}, {
    cobrand => 'camden'
});

$mech->create_contact_ok(body_id => $camden->id, category => 'Potholes', email => 'potholes@camden.fixmystreet.com');
my $staffuser = $mech->create_user_ok( 'staff@example.com', name => 'Staffer', from_body => $camden );

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'camden', 'tfl' ],
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    subtest "hides the TfL River Piers category" => sub {

        my $tfl = $mech->create_body_ok(CAMDEN_MAPIT_ID, 'TfL');
        $mech->create_contact_ok(body_id => $tfl->id, category => 'River Piers', email => 'tfl@example.org');
        $mech->create_contact_ok(body_id => $tfl->id, category => 'River Piers - Cleaning', email => 'tfl@example.org');
        $mech->create_contact_ok(body_id => $tfl->id, category => 'River Piers Damage doors and glass', email => 'tfl@example.org');

        ok $mech->host('camden.fixmystreet.com'), 'set host';

        my $json = $mech->get_ok_json('/report/new/ajax?latitude=51.529432&longitude=-0.124514');
        is_deeply keys %{$json->{by_category}}, ('Potholes',), "Camden doesn't have River Piers category";
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
        my $report = FixMyStreet::DB->resultset('Problem')->search(undef, { order_by => { -desc => 'id' } })->first;
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
    };

    subtest "reports that aren't anonymous still don't show the name" => sub {
        my ($report) = $mech->create_problems_for_body(1, $camden->id, {
            anonymous => 0,
            cobrand => 'camden',
            name => 'Test User',
        });

        $mech->get_ok('/report/' . $report->id);
        $mech->content_lacks('Test User');
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
};

done_testing;
