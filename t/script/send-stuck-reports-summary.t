use FixMyStreet;
BEGIN { FixMyStreet->test_mode(1); }

package FixMyStreet::Cobrand::Test;
use parent 'FixMyStreet::Cobrand::Default';
sub base_url { 'base-url' }
sub do_not_reply_email { 'do-not-reply@testcobrand' }
sub contact_name { 'Test' }

package main;

use Test::LongString;
use FixMyStreet::TestMech;
use FixMyStreet::Script::SendStuckReportsSummary;

my $mech = FixMyStreet::TestMech->new();
$mech->clear_emails_ok;

my $body = $mech->create_body_ok(2237, 'Body', { cobrand => 'test' });
my $graffiti = $mech->create_contact_ok(body_id => $body->id, category => 'Graffiti', email => "GRAF");
my $potholes = $mech->create_contact_ok(body_id => $body->id, category => 'Potholes', email => "POTH");
my $bins = $mech->create_contact_ok(body_id => $body->id, category => 'Bins', email => "BINS");


subtest 'No reports to send' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'test' ],
    }, sub {
        FixMyStreet::Script::SendStuckReportsSummary::run({
            body => $body,
            categories => ['Graffiti', 'Potholes'],
            email => 'out-address@test',
            unconfirmed => 1,
            commit => 1,
        });
        my @emails = $mech->get_email;
        $mech->email_count_is(1);
        my $email = $emails[0];

        is $email->header('Subject'), "Summary of stuck reports for Body", 'correct subject';
        is $email->header('To'), 'out-address@test', 'correct destination';
        is $email->header('From'), 'Test <do-not-reply@testcobrand>', 'correct sender';

        my $email_body = $mech->get_text_body_from_email($email);
        like $email_body, qr/There are 0 stuck reports and 0 unconfirmed reports for categories 'Graffiti' and 'Potholes'/, 'correct overview';
    };
};

subtest 'Reports to send' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'test' ],
    }, sub {
        my ($stuck_graffiti_report) = $mech->create_problems_for_body(1, $body->id, 'TITLE', {
            category => $graffiti->category,
            send_state => 'unprocessed',
            state => 'confirmed',
            send_fail_count => 2,
            send_fail_timestamp => '2025-04-24T13:00:00Z',
            send_fail_reason => "Failed to send over Open311\n\nrequest failed: 500 Internal Server Error\nerror: 500: UPRN 12345 does not have a subscription to be renewed, or is invalid at /data/vhost/open311-adapter.mysociety.org/open311-adapter-2025-04-25T10-56-30/",
        });
        my $graffiti_id = $stuck_graffiti_report->id;
        my ($stuck_potholes_report) = $mech->create_problems_for_body(1, $body->id, 'TITLE', {
            category => $potholes->category,
            send_state => 'unprocessed',
            state => 'confirmed',
            send_fail_count => 3,
            send_fail_timestamp => '2025-04-24T14:00:00Z',
            send_fail_reason => "Failed to send over Open311\n\nrequest failed: 500 Internal Server Error\nerror: 500: [{\"Code\":40,\"Message\":\"There is not an active contract for this address linked to the customer\",\"MessageDetails\":\"   at Contender.BusinessLogic.External.ExternalBL.HandleMicroservice",
        });
        my $pothole_id = $stuck_potholes_report->id;
        my ($stuck_bins_report) = $mech->create_problems_for_body(1, $body->id, ',ITLE', {
            category => $bins->category,
            send_state => 'unprocessed',
            state => 'confirmed',
            send_fail_count => 0,
            send_fail_timestamp => '2025-04-24T13:00:00Z',
            send_fail_reason => 'something went wrong',
        });
        my ($unconfirmed_graffiti_report) = $mech->create_problems_for_body(1, $body->id, 'TITLE', {
            category => $graffiti->category,
            state => 'unconfirmed',
            created => '2025-04-24T11:00:00Z'
        });
        my $graffiti_unconfirmed_id = $unconfirmed_graffiti_report->id;

        $mech->clear_emails_ok;
        FixMyStreet::Script::SendStuckReportsSummary::run({
            body => $body,
            categories => ['Graffiti', 'Potholes'],
            email => 'out-address@test',
            unconfirmed => 1,
            commit => 1,
        });
        my $email = $mech->get_email;

        my $stuck_expected = <<EOF;
Graffiti report base-url/report/$graffiti_id has failed to send 2 times.

The last failure was at 2025-04-24T13:00:00 with error:

UPRN 12345 does not have a subscription to be renewed, or is invalid

------------------------------------------------------------

Potholes report base-url/report/$pothole_id has failed to send 3 times.

The last failure was at 2025-04-24T14:00:00 with error:

[{"Code":40,"Message":"There is not an active contract for this address linked to the customer",...

------------------------------------------------------------
EOF

        my $email_body = $mech->get_text_body_from_email($email);
        is_string_nows $email_body, <<EOF;
There are 2 stuck reports and 1 unconfirmed report for categories 'Graffiti' and 'Potholes'

------------------------------------------------------------

$stuck_expected

Graffiti report base-url/report/$graffiti_unconfirmed_id is unconfirmed.

It was created at 2025-04-24T11:00:00.

------------------------------------------------------------
EOF
        unlike $email_body, qr/Bins/s, 'does not contain the stuck bins report';

        $mech->clear_emails_ok;
        FixMyStreet::Script::SendStuckReportsSummary::run({
            body => $body,
            categories => ['Graffiti', 'Potholes'],
            email => 'out-address@test',
            unconfirmed => 1,
            commit => 1,
        });
        $email = $mech->get_email;

        $email_body = $mech->get_text_body_from_email($email);
        is_string_nows $email_body, <<EOF;
There are 2 stuck reports and 0 unconfirmed reports for categories 'Graffiti' and 'Potholes'

------------------------------------------------------------

$stuck_expected
EOF
        unlike $email_body, qr/Bins/s, 'does not contain the stuck bins report';
    };
};

done_testing();
