use strict;
use warnings;
use Test::More;

BEGIN {
    use FixMyStreet;
    FixMyStreet->test_mode(1);
}

use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

# Front page test

ok $mech->host("www.fixmybarangay.com"), "change host to FixMyBarangay";
FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'fixmybarangay' ],
}, sub {
    $mech->get_ok('/');
};
$mech->content_like( qr/FixMyBarangay/ );

# Set up bodies

my $luz = $mech->create_body_ok( 1, 'Bgy Luz', id => 1 );
$luz->update( { send_method => 'Email' } );

my $bsn = $mech->create_body_ok( 2, 'Bgy BSN', id => 2 );
$bsn->update( { send_method => 'Email' } );

my $dps = $mech->create_body_ok( 3, 'DPS', id => 3 );
$dps->update( { send_method => 'Open311', endpoint => 'http://dps.endpoint.example.com', jurisdiction => 'FMB', api_key => 'test' } );
FixMyStreet::DB->resultset('BodyArea')->find_or_create({ area_id => 1, body_id => $dps->id });
FixMyStreet::DB->resultset('BodyArea')->find_or_create({ area_id => 2, body_id => $dps->id });

# Create contacts for these bodies
# TODO: log in as a Bgy user, and create a report using the front end,
# testing that the drop-down has the right things in it, and so on.

$mech->create_contact_ok(
    body_id => $luz->id, 
    category => 'Streetlight (BGY)',
    email => 'bgy@example.com',
);
$mech->create_contact_ok(
    body_id => $dps->id, 
    category => 'Streetlight (DPS)',
    email => 'LIGHT',
);

# Create a couple of reports

my @reports = $mech->create_problems_for_body( 1, $luz->id, 'Test', {
    cobrand => 'fixmybarangay',
    category => 'Streetlight (BGY)',
});
my $luz_report = $reports[0];

@reports = $mech->create_problems_for_body( 1, $dps->id, 'Test', {
    cobrand => 'fixmybarangay',
    category => 'Streetlight (DPS)',
});
my $dps_report = $reports[0];

$mech->get_ok( '/report/' . $luz_report->id );
$mech->get_ok( '/report/' . $dps_report->id );

# Send the reports

$mech->email_count_is(0);

FixMyStreet::override_config {
    SEND_REPORTS_ON_STAGING => 1,
}, sub {
    FixMyStreet::DB->resultset('Problem')->send_reports('fixmybarangay');
};

# Check BGY one sent by email
my $email = $mech->get_email;
like $email->header('Subject'), qr/Problem Report: Test Test/, 'subject looks okay';
like $email->header('To'), qr/bgy\@example.com/, 'to line looks correct';
$mech->clear_emails_ok;

$luz_report->discard_changes;
$dps_report->discard_changes;
ok $luz_report->whensent, 'Luz report marked as sent';
ok $dps_report->whensent, 'DPS report marked as sent';
is $dps_report->send_method_used, 'Open311', 'DPS report sent via Open311';
is $dps_report->external_id, 248, 'DPS report has right external ID';

my $fmb_test_email = 'luz_test_user@example.com';
my $user = FixMyStreet::DB->resultset('User')->find_or_create( { email => $fmb_test_email, from_body => $luz->id, password => 'fmbsecret' } );
ok $user, "test user does exist";

my $alert = FixMyStreet::DB->resultset('Alert')->find_or_create({
    user => $user,
    parameter => '-0.142497580865087',
    parameter2 => '51.5016605453401',
    alert_type => 'local_problems',
    whensubscribed => '2014-01-01 10:00:00',
    confirmed => 1,
    cobrand => 'fixmybarangay',
});

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'fixmybarangay' ],
}, sub {
    FixMyStreet::DB->resultset('AlertType')->email_alerts();
};

$mech->email_count_is(1);
$email = $mech->get_email;
like $email->body, qr/The following FixMyBarangay reports/, 'Start of email looks correct';
$mech->clear_emails_ok;

$mech->log_out_ok;
$mech->get_ok( '/report/' . $luz_report->id );
$mech->content_lacks( "Remove from site" );
$mech->content_contains( "Report abuse" );

$mech->post_ok('/report/delete/' . $luz_report->id);
is $mech->uri->path, '/report/' . $luz_report->id, "should redirect to report page, deletion ignored";
$luz_report->discard_changes;
is $luz_report->state, 'confirmed', 'should be confirmed';

$user = $mech->log_in_ok($fmb_test_email);

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'fixmybarangay' ],
}, sub {
    $mech->get_ok( '/report/' . $luz_report->id );
};
$mech->content_contains( "Remove from site" );
$mech->content_lacks( "Report abuse" );

$mech->form_id('remove-from-site-form');
$mech->submit_form();
is $mech->uri->path, '/report/' . $luz_report->id, "should redirect to report page, deletion successful";
$luz_report->discard_changes;
is $luz_report->state, 'hidden', 'should be hidden';

$mech->delete_user($fmb_test_email);

$mech->delete_body($luz);
$mech->delete_body($bsn);
$mech->delete_body($dps);

ok $mech->host("www.fixmystreet.com"), "change host back";

done_testing();
