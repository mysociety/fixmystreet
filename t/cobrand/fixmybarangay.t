use strict;
use warnings;
use Test::More;

plan skip_all => 'Skipping Zurich test without FixMyBarangay cobrand'
    unless FixMyStreet::Cobrand->exists('fixmybarangay');

use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

# Front page test

ok $mech->host("www.fixmybarangay.com"), "change host to FixMyBarangay";
$mech->get_ok('/');
$mech->content_like( qr/FixMyBarangay/ );

# Set up bodies

my $luz = $mech->create_body_ok( 1, 'Bgy Luz' );
$luz->update( { send_method => 'Email' } );

my $bsn = $mech->create_body_ok( 2, 'Bgy BSN' );
$bsn->update( { send_method => 'Email' } );

my $dps = $mech->create_body_ok( 3, 'DPS' );
$dps->update( { send_method => 'Open311', endpoint => 'http://dps.endpoint.example.com', jurisdiction => 'FMB', api_key => 'test' } );
FixMyStreet::App->model('DB::BodyArea')->find_or_create({ area_id => 1, body_id => 3 });
FixMyStreet::App->model('DB::BodyArea')->find_or_create({ area_id => 2, body_id => 3 });

# Create contacts for these bodies
# TODO: log in as a Bgy user, and create a report using the front end,
# testing that the drop-down has the right things in it, and so on.

my %contact_params = (
    confirmed => 1,
    deleted => 0,
    editor => 'Test',
    whenedited => \'current_timestamp',
    note => 'Created for test',
);
FixMyStreet::App->model('DB::Contact')->search( {
    email => { 'like', '%example.com' },
} )->delete;
my $contact1 = FixMyStreet::App->model('DB::Contact')->find_or_create( {
    %contact_params,
    body_id => 1, 
    category => 'Streetlight (BGY)',
    email => 'bgy@example.com',
} );
my $contact2 = FixMyStreet::App->model('DB::Contact')->find_or_create( {
    %contact_params,
    body_id => 3, 
    category => 'Streetlight (DPS)',
    email => 'LIGHT',
} );

# Create a couple of reports

my @reports = $mech->create_problems_for_body( 1, 1, 'Test', {
    cobrand => 'fixmybarangay',
    category => 'Streetlight (BGY)',
});
my $luz_report = $reports[0];

@reports = $mech->create_problems_for_body( 1, 3, 'Test', {
    cobrand => 'fixmybarangay',
    category => 'Streetlight (DPS)',
});
my $dps_report = $reports[0];

$mech->get_ok( '/report/' . $luz_report->id );
$mech->get_ok( '/report/' . $dps_report->id );

# Send the reports

$mech->email_count_is(0);

FixMyStreet::App->model('DB::Problem')->send_reports('fixmybarangay');

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

$mech->delete_problems_for_body( 1 );
$mech->delete_problems_for_body( 3 );

ok $mech->host("www.fixmystreet.com"), "change host back";

done_testing();
