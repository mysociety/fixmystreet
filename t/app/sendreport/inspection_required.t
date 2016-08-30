use strict;
use warnings;

use Test::More;

use FixMyStreet;
use FixMyStreet::DB;
use FixMyStreet::TestMech;
use FixMyStreet::SendReport::Email;
use mySociety::Locale;

ok( my $mech = FixMyStreet::TestMech->new, 'Created mech object' );

my $user = $mech->create_user_ok( 'user@example.com' );

my $body = $mech->create_body_ok( 2237, 'Oxfordshire County Council', id => 2237 );
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

subtest 'Report isn’t sent if uninspected' => sub {
    $mech->clear_emails_ok;

    FixMyStreet::DB->resultset('Problem')->send_reports();

    $mech->email_count_is( 0 );
    is $report->whensent, undef, 'Report hasn’t been sent';
};

subtest 'Report is sent when inspected' => sub {
    $mech->clear_emails_ok;
    $report->set_extra_metadata(inspected => 1);
    $report->update;

    FixMyStreet::DB->resultset('Problem')->send_reports();

    $report->discard_changes;
    $mech->email_count_is( 1 );
    ok $report->whensent, 'Report marked as sent';
};

done_testing();

END {
    $mech->delete_body($body);
}
