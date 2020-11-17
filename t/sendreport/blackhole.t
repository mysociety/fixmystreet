use FixMyStreet;
use FixMyStreet::DB;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;

ok( my $mech = FixMyStreet::TestMech->new, 'Created mech object' );

my $user = $mech->create_user_ok( 'user@example.com' );

my $body = $mech->create_body_ok( 2551, 'Bath and North East Somerset Council');
$body->update({ can_be_devolved => 1 });

my $contact = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Play area safety issue',
    email => 'test@example.org',
    send_method => 'Blackhole',
);

my @reports = $mech->create_problems_for_body( 1, $body->id, 'Test', {
    cobrand => 'bathnes',
    category => $contact->category,
    user => $user,
});
my $report = $reports[0];

FixMyStreet::override_config {
    STAGING_FLAGS => { send_reports => 1 },
}, sub {
    subtest "Report isn't sent anywhere" => sub {
        $mech->clear_emails_ok;

        FixMyStreet::Script::Reports::send();

        ok $mech->email_count_is(0), "Report email wasn't sent";

        $report->discard_changes;
        ok $report->whensent, "Report has been marked as sent";
    };
};

done_testing();
