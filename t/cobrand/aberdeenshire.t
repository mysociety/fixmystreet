use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use FixMyStreet::Script::CSVExport;
use FixMyStreet::Script::Alerts;
use File::Temp 'tempdir';

my $mech = FixMyStreet::TestMech->new;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

use_ok 'FixMyStreet::Cobrand::Aberdeenshire';

my $aberdeenshire = $mech->create_body_ok(2242, 'Aberdeenshire Council', { cobrand => 'aberdeenshire' });
my $staff_user = $mech->create_user_ok( 'staff@example.com', name => 'Staff User', from_body => $aberdeenshire );
$mech->create_contact_ok(body_id => $aberdeenshire->id, category => 'Pothole', email => 'potholes@example.org');
(my $report) = $mech->create_problems_for_body(1, $aberdeenshire->id, 'Pothole', {
            category => 'Pothole', cobrand => 'aberdeenshire',
            latitude => 57.27126, longitude => -2.43012, areas => '2648',
            external_id => '9876543'
        });


FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'aberdeenshire' ],
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
        subtest 'CSV has external ID column ' => sub {
            $mech->log_in_ok($staff_user->email);
            $mech->get_ok("/dashboard?export=1");
            $mech->content_contains('"Site Used","Reported As","Confirm ID"', 'CSV content contains "External ID" columns');
            $mech->content_contains('website,aberdeenshire,,9876543', 'CSV contains external ID');

            FixMyStreet::Script::CSVExport::process(dbh => FixMyStreet::DB->schema->storage->dbh);
            $mech->get_ok("/dashboard?export=1");
            $mech->content_contains('website,aberdeenshire,,9876543', 'Pre-generated CSV contains external ID');
            $mech->log_out_ok;
        };

        subtest 'Front page has correct wording' => sub {
            $mech->get_ok("/");
            $mech->content_contains("<h1>Report a problem</h1>");
            $mech->content_contains("Report, view and check progress on a road, roadside");
        };

        subtest 'FAQ page has correct wording' => sub {
            $mech->get_ok("/faq");
            $mech->content_contains("This service is for reporting issues on roads, roadside and pavements");
            $mech->content_contains("You will need to either provide your email address or sign in with");
            $mech->content_contains("service as a mobile app");
        };

        subtest 'State changes aren’t shown in update emails' => sub {
            my $alert_user = $mech->create_user_ok('alerts@example.com', name => 'Alert User');

            my $alert = FixMyStreet::DB->resultset('Alert')->create({
                user       => $alert_user,
                alert_type => 'new_updates',
                parameter  => $report->id,
                confirmed  => 1,
                cobrand    => 'aberdeenshire',
                whensubscribed => DateTime->now->subtract(days => 1),
            });
            ok $alert, 'created alert for user';

            $mech->create_comment_for_problem(
                $report, $staff_user, 'Staff User', 'Update with state change',
                'f', 'confirmed', 'investigating',
                { confirmed => DateTime->now }
            );

            $mech->clear_emails_ok;
            FixMyStreet::Script::Alerts::send_updates();

            $mech->email_count_is(1);
            my $email_body = $mech->get_text_body_from_email;

            like $email_body, qr/Update with state change/, 'email contains the update text';
            unlike $email_body, qr/State changed to:/, 'email does not contain state change text for Aberdeenshire';
        };
};



done_testing();
