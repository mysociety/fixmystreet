use FixMyStreet;
use FixMyStreet::DB;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;

ok( my $mech = FixMyStreet::TestMech->new, 'Created mech object' );

my $user = $mech->create_user_ok( 'user@example.com' );

my $body = $mech->create_body_ok( 2237, 'Oxfordshire County Council');
# $body->update({ send_method => 'Email' });

my $contact = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Pothole',
    email => 'test@example.org',
);
$contact->set_extra_metadata(inspection_required => 1);
$contact->update;

my @reports = $mech->create_problems_for_body( 1, $body->id, 'Test', {
    cobrand => 'oxfordshire',
    category => $contact->category,
    user => $user,
});
my $report = $reports[0];

subtest "Report isn't sent if uninspected" => sub {
    $mech->clear_emails_ok;

    FixMyStreet::Script::Reports::send();

    $mech->email_count_is( 0 );
    is $report->whensent, undef, "Report hasn't been sent";
};

subtest 'Report is sent when inspected' => sub {
    $mech->clear_emails_ok;
    $report->set_extra_metadata(inspected => 1);
    $report->update;

    FixMyStreet::Script::Reports::send();

    $report->discard_changes;
    $mech->email_count_is( 1 );
    ok $report->whensent, 'Report marked as sent';
};

subtest 'Uninspected report is sent when made by trusted user' => sub {
    $mech->clear_emails_ok;
    $report->unset_extra_metadata('inspected');
    $report->whensent( undef );
    $report->update;

    $user->user_body_permissions->find_or_create({
        body => $body,
        permission_type => 'trusted',
    });
    ok  $user->has_permission_to('trusted', $report->bodies_str_ids), 'User can make trusted reports';

    FixMyStreet::Script::Reports::send();

    $report->discard_changes;
    $mech->email_count_is( 1 );
    ok $report->whensent, 'Report marked as sent';
    is $report->get_extra_metadata('inspected'), undef, 'Report not marked as inspected';
};

subtest "Uninspected report isn't sent when user rep is too low" => sub {
    $mech->clear_emails_ok;
    $report->whensent( undef );
    $report->update;

    $user->user_body_permissions->delete;
    $user->set_extra_metadata(reputation => 15);
    $user->update;

    $contact->set_extra_metadata(reputation_threshold => 20);
    $contact->update;

    FixMyStreet::Script::Reports::send();

    $report->discard_changes;
    $mech->email_count_is( 0 );
    is $report->whensent, undef, "Report hasn't been sent";
};

subtest 'Uninspected report is sent when user rep is high enough' => sub {
    $user->set_extra_metadata(reputation => 21);
    $user->update;

    FixMyStreet::Script::Reports::send();

    $report->discard_changes;
    $mech->email_count_is( 1 );
    ok $report->whensent, 'Report marked as sent';
    is $report->get_extra_metadata('inspected'), undef, 'Report not marked as inspected';
};

done_testing();
