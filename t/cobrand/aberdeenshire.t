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

        subtest 'open311_get_update_munging handles defect superseding' => sub {
            my $cobrand = FixMyStreet::Cobrand::Aberdeenshire->new;

            # Create a superseded report with external_id starting with DEFECT_
            my ($superseded_report) = $mech->create_problems_for_body(1, $aberdeenshire->id, 'Superseded Report', {
                category => 'Pothole',
                cobrand => 'aberdeenshire',
                latitude => 57.28126,
                longitude => -2.44012,
                areas => '2648',
                external_id => 'DEFECT_12345',
                state => 'confirmed'
            });

            # Create a new superseding report
            my ($superseding_report) = $mech->create_problems_for_body(1, $aberdeenshire->id, 'Superseding Report', {
                category => 'Pothole',
                cobrand => 'aberdeenshire',
                latitude => 57.28126,
                longitude => -2.44012,
                areas => '2648',
                external_id => 'DEFECT_67890',
                state => 'confirmed'
            });

            # Create some users who have alerts on the superseded report
            my $alert_user1 = $mech->create_user_ok('alertuser1@example.com', name => 'Alert User 1');
            my $alert_user2 = $mech->create_user_ok('alertuser2@example.com', name => 'Alert User 2');

            my $alert1 = FixMyStreet::DB->resultset('Alert')->create({
                user => $alert_user1,
                alert_type => 'new_updates',
                parameter => $superseded_report->id,
                confirmed => 1,
                cobrand => 'aberdeenshire',
                lang => 'en-gb',
                cobrand_data => '',
                whensubscribed => DateTime->now->subtract(days => 1),
            });

            my $alert2 = FixMyStreet::DB->resultset('Alert')->create({
                user => $alert_user2,
                alert_type => 'new_updates',
                parameter => $superseded_report->id,
                confirmed => 1,
                cobrand => 'aberdeenshire',
                lang => 'en-gb',
                cobrand_data => '',
                whensubscribed => DateTime->now->subtract(days => 1),
            });

            # Create a comment/update for the superseding report that indicates superseding
            my $superseding_comment = $mech->create_comment_for_problem(
                $superseding_report, $staff_user, 'System', 'This defect supersedes DEFECT_12345',
                'f', 'confirmed', 'confirmed',
                { confirmed => DateTime->now, external_id => 'UPDATE_001' }
            );

            # Verify initial state - superseded report should be confirmed, alerts should be active
            is $superseded_report->state, 'confirmed', 'Superseded report is initially confirmed';
            is $alert1->whendisabled, undef, 'First alert is initially active';
            is $alert2->whendisabled, undef, 'Second alert is initially active';

            # Test the method with a proper superseding request
            my $request = {
                extras => {
                    supersedes => 'DEFECT_12345'
                }
            };

            $cobrand->open311_get_update_munging($superseding_comment, 'confirmed', $request);

            # Refresh objects from database
            $superseded_report->discard_changes;
            $alert1->discard_changes;
            $alert2->discard_changes;

            # Verify the superseded report is now hidden
            is $superseded_report->state, 'hidden', 'Superseded report is now hidden';

            # Verify old alerts are disabled
            isnt $alert1->whendisabled, undef, 'First alert has been disabled';
            isnt $alert2->whendisabled, undef, 'Second alert has been disabled';

            # Verify new alerts have been created for the superseding report
            my $new_alerts = FixMyStreet::DB->resultset('Alert')->search({
                alert_type => 'new_updates',
                parameter => $superseding_report->id,
                whendisabled => undef
            });

            is $new_alerts->count, 2, 'Two new alerts created for superseding report';

            my @new_alert_users = sort map { $_->user->email } $new_alerts->all;
            is_deeply \@new_alert_users, [$alert_user1->email, $alert_user2->email],
                'New alerts created for the same users';
        };

        subtest 'open311_get_update_munging ignores non-defect superseding' => sub {
            my $cobrand = FixMyStreet::Cobrand::Aberdeenshire->new;

            my ($test_report) = $mech->create_problems_for_body(1, $aberdeenshire->id, 'Test Report', {
                category => 'Pothole',
                cobrand => 'aberdeenshire',
                external_id => 'NON_DEFECT_123',
                state => 'confirmed'
            });

            my $comment = $mech->create_comment_for_problem(
                $test_report, $staff_user, 'System', 'Some update',
                'f', 'confirmed', 'confirmed'
            );

            # Test with supersedes value that doesn't start with DEFECT_
            my $request = {
                extras => {
                    supersedes => 'INCIDENT_123'
                }
            };

            my $initial_state = $test_report->state;
            $cobrand->open311_get_update_munging($comment, 'confirmed', $request);
            $test_report->discard_changes;

            is $test_report->state, $initial_state, 'Report state unchanged for non-DEFECT superseding';
        };

        subtest 'open311_get_update_munging ignores missing supersedes' => sub {
            my $cobrand = FixMyStreet::Cobrand::Aberdeenshire->new;

            my ($test_report) = $mech->create_problems_for_body(1, $aberdeenshire->id, 'Test Report 2', {
                category => 'Pothole',
                cobrand => 'aberdeenshire',
                external_id => 'DEFECT_999',
                state => 'confirmed'
            });

            my $comment = $mech->create_comment_for_problem(
                $test_report, $staff_user, 'System', 'Some update',
                'f', 'confirmed', 'confirmed'
            );

            # Test with no supersedes field
            my $request = {
                extras => {}
            };

            my $initial_state = $test_report->state;
            $cobrand->open311_get_update_munging($comment, 'confirmed', $request);
            $test_report->discard_changes;

            is $test_report->state, $initial_state, 'Report state unchanged when supersedes is missing';
        };

        subtest 'open311_get_update_munging ignores nonexistent superseded report' => sub {
            my $cobrand = FixMyStreet::Cobrand::Aberdeenshire->new;

            my ($test_report) = $mech->create_problems_for_body(1, $aberdeenshire->id, 'Test Report 3', {
                category => 'Pothole',
                cobrand => 'aberdeenshire',
                external_id => 'DEFECT_888',
                state => 'confirmed'
            });

            my $comment = $mech->create_comment_for_problem(
                $test_report, $staff_user, 'System', 'Some update',
                'f', 'confirmed', 'confirmed'
            );

            # Test with supersedes value that doesn't match any existing report
            my $request = {
                extras => {
                    supersedes => 'DEFECT_NONEXISTENT'
                }
            };

            my $initial_state = $test_report->state;
            $cobrand->open311_get_update_munging($comment, 'confirmed', $request);
            $test_report->discard_changes;

            is $test_report->state, $initial_state, 'Report state unchanged when superseded report not found';
        };

        subtest 'open311_get_update_munging ignores already hidden reports' => sub {
            my $cobrand = FixMyStreet::Cobrand::Aberdeenshire->new;

            # Create a superseded report that's already hidden
            my ($hidden_report) = $mech->create_problems_for_body(1, $aberdeenshire->id, 'Hidden Report', {
                category => 'Pothole',
                cobrand => 'aberdeenshire',
                external_id => 'DEFECT_HIDDEN',
                state => 'hidden'
            });

            my ($superseding_report) = $mech->create_problems_for_body(1, $aberdeenshire->id, 'New Report', {
                category => 'Pothole',
                cobrand => 'aberdeenshire',
                external_id => 'DEFECT_NEW_2',
                state => 'confirmed'
            });

            my $comment = $mech->create_comment_for_problem(
                $superseding_report, $staff_user, 'System', 'Some update',
                'f', 'confirmed', 'confirmed'
            );

            # Test with supersedes pointing to already hidden report
            my $request = {
                extras => {
                    supersedes => 'DEFECT_HIDDEN'
                }
            };

            # Should not create any alerts since no hidden report processing should occur
            my $initial_alert_count = FixMyStreet::DB->resultset('Alert')->search({
                alert_type => 'new_updates',
                parameter => $superseding_report->id
            })->count;

            $cobrand->open311_get_update_munging($comment, 'confirmed', $request);

            my $final_alert_count = FixMyStreet::DB->resultset('Alert')->search({
                alert_type => 'new_updates',
                parameter => $superseding_report->id
            })->count;

            is $final_alert_count, $initial_alert_count, 'No new alerts created when superseding already hidden report';
        };

        subtest 'open311_report_fetched handles defect superseding' => sub {
            my $cobrand = FixMyStreet::Cobrand::Aberdeenshire->new;

            # Create a superseded report with external_id starting with DEFECT_
            my ($superseded_report) = $mech->create_problems_for_body(1, $aberdeenshire->id, 'Superseded Fetched Report', {
                category => 'Pothole',
                cobrand => 'aberdeenshire',
                latitude => 57.29126,
                longitude => -2.45012,
                areas => '2648',
                external_id => 'DEFECT_FETCH_123',
                state => 'confirmed'
            });

            # Create a new fetched report that supersedes the existing one
            my ($fetched_report) = $mech->create_problems_for_body(1, $aberdeenshire->id, 'Fetched Superseding Report', {
                category => 'Pothole',
                cobrand => 'aberdeenshire',
                latitude => 57.29126,
                longitude => -2.45012,
                areas => '2648',
                external_id => 'DEFECT_FETCH_456',
                state => 'confirmed'
            });

            # Create users with alerts on the superseded report
            my $alert_user1 = $mech->create_user_ok('fetchalertuser1@example.com', name => 'Fetch Alert User 1');
            my $alert_user2 = $mech->create_user_ok('fetchalertuser2@example.com', name => 'Fetch Alert User 2');

            my $alert1 = FixMyStreet::DB->resultset('Alert')->create({
                user => $alert_user1,
                alert_type => 'new_updates',
                parameter => $superseded_report->id,
                confirmed => 1,
                cobrand => 'aberdeenshire',
                lang => 'en-gb',
                cobrand_data => '',
                whensubscribed => DateTime->now->subtract(days => 1),
            });

            my $alert2 = FixMyStreet::DB->resultset('Alert')->create({
                user => $alert_user2,
                alert_type => 'new_updates',
                parameter => $superseded_report->id,
                confirmed => 1,
                cobrand => 'aberdeenshire',
                lang => 'en-gb',
                cobrand_data => '',
                whensubscribed => DateTime->now->subtract(days => 1),
            });

            # Verify initial state
            is $superseded_report->state, 'confirmed', 'Superseded report is initially confirmed';
            is $alert1->whendisabled, undef, 'First alert is initially active';
            is $alert2->whendisabled, undef, 'Second alert is initially active';

            # Test the method with a fetched report that supersedes another
            my $request = {
                extras => {
                    supersedes => 'DEFECT_FETCH_123'
                }
            };

            $cobrand->open311_report_fetched($fetched_report, $request);

            # Refresh objects from database
            $superseded_report->discard_changes;
            $alert1->discard_changes;
            $alert2->discard_changes;

            # Verify the superseded report is now hidden
            is $superseded_report->state, 'hidden', 'Superseded report is now hidden';

            # Verify old alerts are disabled
            isnt $alert1->whendisabled, undef, 'First alert has been disabled';
            isnt $alert2->whendisabled, undef, 'Second alert has been disabled';

            # Verify new alerts have been created for the fetched report
            my $new_alerts = FixMyStreet::DB->resultset('Alert')->search({
                alert_type => 'new_updates',
                parameter => $fetched_report->id,
                whendisabled => undef
            });

            is $new_alerts->count, 2, 'Two new alerts created for fetched report';

            my @new_alert_users = sort map { $_->user->email } $new_alerts->all;
            is_deeply \@new_alert_users, [$alert_user1->email, $alert_user2->email],
                'New alerts created for the same users';
        };

        subtest 'open311_report_fetched ignores non-defect superseding' => sub {
            my $cobrand = FixMyStreet::Cobrand::Aberdeenshire->new;

            my ($test_report) = $mech->create_problems_for_body(1, $aberdeenshire->id, 'Test Fetched Report', {
                category => 'Pothole',
                cobrand => 'aberdeenshire',
                external_id => 'NON_DEFECT_FETCH_123',
                state => 'confirmed'
            });

            # Test with supersedes value that doesn't start with DEFECT_
            my $request = {
                extras => {
                    supersedes => 'INCIDENT_FETCH_123'
                }
            };

            my $initial_state = $test_report->state;
            $cobrand->open311_report_fetched($test_report, $request);
            $test_report->discard_changes;

            is $test_report->state, $initial_state, 'Report state unchanged for non-DEFECT superseding in fetched report';
        };

        subtest 'open311_report_fetched ignores missing supersedes' => sub {
            my $cobrand = FixMyStreet::Cobrand::Aberdeenshire->new;

            my ($test_report) = $mech->create_problems_for_body(1, $aberdeenshire->id, 'Test Fetched Report 2', {
                category => 'Pothole',
                cobrand => 'aberdeenshire',
                external_id => 'DEFECT_FETCH_999',
                state => 'confirmed'
            });

            # Test with no supersedes field
            my $request = {
                extras => {}
            };

            my $initial_state = $test_report->state;
            $cobrand->open311_report_fetched($test_report, $request);
            $test_report->discard_changes;

            is $test_report->state, $initial_state, 'Report state unchanged when supersedes is missing in fetched report';
        };

        subtest 'open311_report_fetched ignores nonexistent superseded report' => sub {
            my $cobrand = FixMyStreet::Cobrand::Aberdeenshire->new;

            my ($test_report) = $mech->create_problems_for_body(1, $aberdeenshire->id, 'Test Fetched Report 3', {
                category => 'Pothole',
                cobrand => 'aberdeenshire',
                external_id => 'DEFECT_FETCH_888',
                state => 'confirmed'
            });

            # Test with supersedes value that doesn't match any existing report
            my $request = {
                extras => {
                    supersedes => 'DEFECT_FETCH_NONEXISTENT'
                }
            };

            my $initial_state = $test_report->state;
            $cobrand->open311_report_fetched($test_report, $request);
            $test_report->discard_changes;

            is $test_report->state, $initial_state, 'Report state unchanged when superseded report not found in fetched report';
        };

        subtest 'open311_report_fetched ignores already hidden reports' => sub {
            my $cobrand = FixMyStreet::Cobrand::Aberdeenshire->new;

            # Create a superseded report that's already hidden
            my ($hidden_report) = $mech->create_problems_for_body(1, $aberdeenshire->id, 'Hidden Fetched Report', {
                category => 'Pothole',
                cobrand => 'aberdeenshire',
                external_id => 'DEFECT_FETCH_HIDDEN',
                state => 'hidden'
            });

            my ($fetched_report) = $mech->create_problems_for_body(1, $aberdeenshire->id, 'New Fetched Report', {
                category => 'Pothole',
                cobrand => 'aberdeenshire',
                external_id => 'DEFECT_FETCH_NEW_2',
                state => 'confirmed'
            });

            # Test with supersedes pointing to already hidden report
            my $request = {
                extras => {
                    supersedes => 'DEFECT_FETCH_HIDDEN'
                }
            };

            # Should not create any alerts since no hidden report processing should occur
            my $initial_alert_count = FixMyStreet::DB->resultset('Alert')->search({
                alert_type => 'new_updates',
                parameter => $fetched_report->id
            })->count;

            $cobrand->open311_report_fetched($fetched_report, $request);

            my $final_alert_count = FixMyStreet::DB->resultset('Alert')->search({
                alert_type => 'new_updates',
                parameter => $fetched_report->id
            })->count;

            is $final_alert_count, $initial_alert_count, 'No new alerts created when superseding already hidden report in fetched report';
        };
};



done_testing();
