use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use FixMyStreet::Script::CSVExport;
use Test::MockTime 'set_fixed_time';
use File::Temp 'tempdir';

my $mech = FixMyStreet::TestMech->new;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

use_ok 'FixMyStreet::Cobrand::Surrey';

my $surrey = $mech->create_body_ok(2242, 'Surrey County Council', { cobrand => 'surrey' });
my $surrey_staff_user = $mech->create_user_ok( 'staff@example.com', name => 'Staff User', from_body => $surrey );
$mech->create_contact_ok(body_id => $surrey->id, category => 'Potholes', email => 'potholes@example.org');
(my $report) = $mech->create_problems_for_body(1, $surrey->id, 'Pothole', {
            category => 'Potholes', cobrand => 'surrey',
            latitude => 51.293415, longitude => -0.441269, areas => '2242',
        });

my $guildford = $mech->create_body_ok(2452, 'Guildford Borough Council');
$mech->create_contact_ok(body_id => $guildford->id, category => 'Flytipping', email => 'flytipping@example.org');

my $UPLOAD_DIR = tempdir( CLEANUP => 1 );
FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'surrey' ],
    MAPIT_URL => 'http://mapit.uk/',
    PHOTO_STORAGE_OPTIONS => { UPLOAD_DIR => $UPLOAD_DIR },
    COBRAND_FEATURES => {
        anonymous_account => {
            surrey => 'anonymous',
        },
    },
}, sub {
        subtest 'CSV has Subscribers column populated by "alerts" registered on problem' => sub {
            $mech->log_in_ok($surrey_staff_user->email);
            $mech->get_ok("/dashboard?export=1");
            $mech->content_contains('"Site Used","Reported As",Subscribers', 'CSV content contains "Subscribers" column');
            $mech->content_contains('website,surrey,,0', 'CSV has 0 subscribers to report as reporter is not subscribed');
            $mech->log_out_ok;
            for my $update (
                {
                    name => 'John Groats',
                    email => 'notify@example.org',
                    text => 'Still there',
                    update_no => 1,
                },
                {
                    name => 'Joan Smith',
                    email => 'tome@example.org',
                    text => 'And still there',
                    update_no => 2,
                }
            ) {
                $mech->get_ok('/report/' . $report->id);
                $mech->submit_form_ok({ with_fields => {update => $update->{text}, name => $update->{name}, username_register => $update->{email}} });
                FixMyStreet::Script::Reports::send();
                my @emails = $mech->get_email;
                my $link = $mech->get_link_from_email($emails[0]); # Most recent email to confirm update
                $mech->get_ok( $link );
                $mech->log_in_ok($surrey_staff_user->email);
                $mech->get_ok("/dashboard?export=1");
                $mech->content_contains('website,surrey,,' . $update->{update_no}, 'CSV Subscriber number is ' . $update->{update_no});
                $mech->log_out_ok;
                $mech->clear_emails_ok;
            }
            FixMyStreet::Script::CSVExport::process(dbh => FixMyStreet::DB->schema->storage->dbh);
            $mech->log_in_ok($surrey_staff_user->email);
            $mech->get_ok("/dashboard?export=1");
            $mech->content_contains('website,surrey,,2', 'CSV Subscriber number is 2 from pre-generated csv');
            $mech->log_out_ok;
        };

        subtest 'Old reports are not shown on Surrey cobrand' => sub {
            set_fixed_time('2024-09-20T12:00:00');
            note 'A newly created report is shown on Surrey cobrand';
            my $json = $mech->get_ok_json('/around?ajax=1&bbox=-0.45869262976076,51.28481314324,-0.42367370886232,51.302390882532');
            is_deeply($json->{pins}, [
                [ "51.293415", "-0.441269", "yellow", $report->id, $report->title, "", 'false' ],
            ], 'Problem is initially included in Surrey cobrand');

            note 'Making the report predate the cut-off excludes it from Surrey cobrand';
            my $dt = DateTime->new(year => 2024, month => 9, day => 1, hour => 12);
            $report->update({
                created => $dt,
                confirmed => $dt,
            });
            $json = $mech->get_ok_json('/around?ajax=1&bbox=-0.45869262976076,51.28481314324,-0.42367370886232,51.302390882532');
            is_deeply($json->{pins}, [], 'Problem is now excluded from Surrey cobrand');

            note 'Borough reports are excluded from Surrey cobrand if old enough too.';
            $report->update({
                bodies_str => $guildford->id,
                category => 'Flytipping',
            });
            $json = $mech->get_ok_json('/around?ajax=1&bbox=-0.45869262976076,51.28481314324,-0.42367370886232,51.302390882532');
            is_deeply($json->{pins}, [], 'Borough problem is excluded from Surrey cobrand');

            note 'Reports fetched over Open311 are included even if they predate cut-off';
            $dt = DateTime->new(year => 2024, month => 8, day => 1, hour => 12);
            $report->update({
                bodies_str => $surrey->id,
                category => 'Potholes',
                service => 'Open311',
                created => $dt,
                confirmed => $dt,
            });
            $json = $mech->get_ok_json('/around?ajax=1&bbox=-0.45869262976076,51.28481314324,-0.42367370886232,51.302390882532');
            is_deeply($json->{pins}, [
                [ "51.293415", "-0.441269", "yellow", $report->id, $report->title, "", 'false' ],
            ], 'Open311 report is initially in Surrey cobrand');
        };

    subtest 'Get error when email included in report' => sub {
        $mech->get_ok('/report/new?longitude=-0.441269&latitude=51.293415');
        $mech->submit_form_ok({ with_fields => { category => 'Potholes', title => 'Potholes', detail => 'On main road', name => 'Bob Betts', username_register => 'user@example.org' } });
        $mech->content_contains('Click the link in our confirmation email to publish your problem', 'Detail field without email proceeds normally');
        $mech->get_ok('/report/new?longitude=-0.441269&latitude=51.293415');
        $mech->submit_form_ok({ with_fields => { category => 'Potholes', title => 'Potholes', detail => 'On main road. Contact me at user@example.org', name => 'Bob Betts', username_register => 'user@example.org' } });
        $mech->content_contains("<p class='form-error'>Please remove any email addresses and other personal information from your report", "Report detail with email gives error");
        $mech->get_ok('/report/new?longitude=-0.441269&latitude=51.293415');
        $mech->submit_form_ok({ with_fields => { category => 'Potholes', title => 'Potholes contact me me@me.co.uk', detail => 'On main road', name => 'Bob Betts', username_register => 'user@example.org' } });
        $mech->content_contains("<p class='form-error'>Please remove any email addresses and other personal information from your report", "Report title with email gives error");
        $mech->clear_emails_ok;
    };

};



done_testing();
