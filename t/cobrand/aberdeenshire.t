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

my $aberdeenshire = $mech->create_body_ok(2648, 'Aberdeenshire Council', { cobrand => 'aberdeenshire' });
my $staff_user = $mech->create_user_ok( 'staff@example.com', name => 'Staff User', from_body => $aberdeenshire );
$mech->create_contact_ok(body_id => $aberdeenshire->id, category => 'Pothole', email => 'potholes@example.org');
$mech->create_contact_ok(body_id => $aberdeenshire->id, category => 'Surface Issue', email => 'surface_issue@example.org');
(my $report) = $mech->create_problems_for_body(1, $aberdeenshire->id, 'Pothole', {
            category => 'Pothole', cobrand => 'aberdeenshire',
            latitude => 57.27126, longitude => -2.43012, areas => '2648',
            external_id => '9876543'
        });

my $UPLOAD_DIR = tempdir( CLEANUP => 1 );
FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'aberdeenshire' ],
    MAPIT_URL => 'http://mapit.uk/',
    PHOTO_STORAGE_OPTIONS => { UPLOAD_DIR => $UPLOAD_DIR }, # ensure cached CSVs are tidied
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

        subtest 'Old reports are not shown on Aberdeenshire cobrand' => sub {
            note 'A newly created report is shown on Aberdeenshire cobrand';
            my $json = $mech->get_ok_json('/around?ajax=1&bbox=-2.43112,57.27026,-2.42912,57.27226');
            is_deeply($json->{pins}, [
                [ "57.27126", "-2.43012", "red", $report->id, $report->title, "", 'false' ],
            ], 'Problem is initially included in Aberdeenshire cobrand');

            note 'Making the report predate the cut-off excludes it from Aberdeenshire cobrand';
            my $dt = DateTime->new(year => 2024, month => 9, day => 1, hour => 12);
            $report->update({
                created => $dt,
                confirmed => $dt,
            });
            $json = $mech->get_ok_json('/around?ajax=1&bbox=-2.43112,57.27026,-2.42912,57.27226');
            is_deeply($json->{pins}, [], 'Problem is now excluded from Aberdeenshire cobrand');


            note 'Reports fetched over Open311 are included even if they predate cut-off';
            $dt = DateTime->new(year => 2024, month => 8, day => 1, hour => 12);
            $report->update({
                bodies_str => $aberdeenshire->id,
                category => 'Potholes',
                service => 'Open311',
                created => $dt,
                confirmed => $dt,
            });
            $json = $mech->get_ok_json('/around?ajax=1&show_old_reports=1&bbox=-2.43112,57.27026,-2.42912,57.27226');
            is_deeply($json->{pins}, [
                [ "57.27126", "-2.43012", "red", $report->id, $report->title, "", 'false' ],
            ], 'Open311 report is initially in Aberdeenshire cobrand');
        };

        subtest 'Category changes are passed to Open311' => sub {
            my $cobrand = FixMyStreet::Cobrand::Aberdeenshire->new;

            my $comment = $mech->create_comment_for_problem(
                $report, $staff_user, 'Staff User', 'Category changed from Pothole to Surface Issue',
                'f', 'confirmed', 'confirmed',
                { confirmed => DateTime->now }
            );
            $report->update({ category => 'Surface Issue' });

            my $params = {};
            $cobrand->open311_munge_update_params($params, $comment);

            is $params->{service_code}, 'surface_issue@example.org', 'Service code is set from contact email';

            # Test with comment that doesn't contain "Category changed"
            my $regular_comment = $mech->create_comment_for_problem(
                $report, $staff_user, 'Staff User', 'Regular update comment',
                'f', 'confirmed', 'confirmed',
                { confirmed => DateTime->now }
            );

            $params = {};
            $cobrand->open311_munge_update_params($params, $regular_comment);

            is scalar keys %$params, 0, 'No parameters added for non-category change comments';
        };

        subtest "sends branded confirmation emails" => sub {
            $mech->log_out_ok;
            $mech->clear_emails_ok;
            $mech->get_ok('/around');
            $mech->submit_form_ok( { with_fields => { pc => 'AB51 5JQ', } },
                "submit location" );

            # click through to the report page
            $mech->follow_link_ok( { text_regex => qr/skip this step/i, },
                "follow 'skip this step' link" );

            $mech->submit_form_ok(
                {
                    button      => 'submit_register',
                    with_fields => {
                        title         => 'Test Report',
                        detail        => 'Test report details.',
                        photo1        => '',
                        name          => 'Joe Bloggs',
                        username_register => 'test-1@example.com',
                        category      => 'Pothole',
                    }
                },
                "submit good details"
            );

            $mech->email_count_is(1);
            my $email = $mech->get_email;
            ok $email, "got an email";
            like $mech->get_text_body_from_email($email), qr/you will need to confirm.*your submission.*Once you do so, your report will be sent to us/, "confirmation email contains custom Aberdeenshire wording";
            like $mech->get_html_body_from_email($email), qr/you will need to confirm your submission.*Once you do so, your report will be sent to us/s, "HTML confirmation email contains custom Aberdeenshire wording";

            $mech->clear_emails_ok;
        };
};



done_testing();
