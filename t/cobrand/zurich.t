# TODO
# Overdue alerts 

use strict;
use warnings;
use DateTime;
use Test::More;

plan skip_all => 'Skipping Zurich test without Zurich cobrand'
    unless FixMyStreet::Cobrand->exists('zurich');

use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

# Front page test
ok $mech->host("zurich.fixmystreet.com"), "change host to Zurich";
$mech->get_ok('/');
$mech->content_like( qr/zurich/i );

# Set up bodies
my $zurich = $mech->create_body_ok( 1, 'Zurich' );
$zurich->parent( undef );
$zurich->update;
my $division = $mech->create_body_ok( 2, 'Division 1' );
$division->parent( $zurich->id );
$division->send_method( 'Zurich' );
$division->endpoint( 'division@example.org' );
$division->update;
my $subdivision = $mech->create_body_ok( 3, 'Subdivision A' );
$subdivision->parent( $division->id );
$subdivision->send_method( 'Zurich' );
$subdivision->endpoint( 'subdivision@example.org' );
$subdivision->update;
my $external_body = $mech->create_body_ok( 4, 'External Body' );
$external_body->send_method( 'Zurich' );
$external_body->endpoint( 'external_body@example.org' );
$external_body->update;

my @reports = $mech->create_problems_for_body( 1, 2, 'Test', {
    state              => 'unconfirmed',
    confirmed          => undef,
    cobrand            => 'zurich',
});
my $report = $reports[0];

$mech->get_ok( '/report/' . $report->id );
$mech->content_contains('&Uuml;berpr&uuml;fung ausstehend');

# Check logging in to deal with this report
$mech->get_ok( '/admin' );
is $mech->uri->path, '/auth', "got sent to the sign in page";

my $user = $mech->log_in_ok( 'dm1@example.org') ;
$user->from_body( undef );
$user->update;
$mech->get_ok( '/admin' );
is $mech->uri->path, '/my', "got sent to /my";
$user->from_body( 2 );
$user->update;

$mech->get_ok( '/admin' );
is $mech->uri->path, '/admin', "am logged in";

$mech->content_contains( 'report_edit/' . $report->id );
$mech->content_contains( DateTime->now->strftime("%d.%m.%Y") );
$mech->content_contains( 'Erfasst' );

$mech->get_ok( '/admin/report_edit/' . $report->id );
$mech->content_contains( 'Unbest&auml;tigt' ); # Unconfirmed email
$mech->submit_form_ok( { with_fields => { state => 'confirmed' } } );
$mech->get_ok( '/report/' . $report->id );
$mech->content_contains('Aufgenommen');
$mech->content_contains('Test Test');
$mech->content_lacks('photo/' . $report->id . '.jpeg');
$mech->email_count_is(0);

# Photo publishing
$mech->get_ok( '/admin/report_edit/' . $report->id );
$mech->submit_form_ok( { with_fields => { publish_photo => 1 } } );
$mech->get_ok( '/report/' . $report->id );
$mech->content_contains('photo/' . $report->id . '.jpeg');

# Internal notes
$mech->get_ok( '/admin/report_edit/' . $report->id );
$mech->submit_form_ok( { with_fields => { internal_notes => 'Some internal notes.' } } );
$mech->content_contains( 'Some internal notes' );

# Original description
$mech->submit_form_ok( { with_fields => { detail => 'Edited details text.' } } );
$mech->content_contains( 'Edited details text.' );
$mech->content_contains( 'Originaltext: &ldquo;Test Test 1 for 2 Detail&rdquo;' );

$mech->get_ok( '/admin/report_edit/' . $report->id );
$mech->submit_form_ok( { with_fields => { body_subdivision => 3 } } );

$mech->get_ok( '/report/' . $report->id );
$mech->content_contains('In Bearbeitung');
$mech->content_contains('Test Test');

FixMyStreet::App->model('DB::Problem')->send_reports('zurich');
my $email = $mech->get_email;
like $email->header('Subject'), qr/Neue Meldung/, 'subject looks okay';
like $email->header('To'), qr/subdivision\@example.org/, 'to line looks correct';
$mech->clear_emails_ok;

$mech->log_out_ok;

$user = $mech->log_in_ok( 'sdm1@example.org') ;
$mech->get_ok( '/admin' );
is $mech->uri->path, '/my', "got sent to /my";
$user->from_body( 3 );
$user->update;

$mech->get_ok( '/admin' );
is $mech->uri->path, '/admin', "am logged in";

$mech->content_contains( 'report_edit/' . $report->id );
$mech->content_contains( DateTime->now->strftime("%d.%m.%Y") );
$mech->content_contains( 'In Bearbeitung' );

$mech->get_ok( '/admin/report_edit/' . $report->id );
$mech->content_contains( 'Some internal notes' );

$mech->submit_form_ok( { with_fields => { status_update => 'This is an update.' } } );
is $mech->uri->path, '/admin/report_edit/' . $report->id, "still on edit page";
$mech->content_contains('This is an update');
ok $mech->form_with_fields( 'status_update' );
$mech->submit_form_ok( { button => 'no_more_updates' } );
is $mech->uri->path, '/admin/summary', "redirected now finished with report.";

$mech->get_ok( '/report/' . $report->id );
$mech->content_contains('In Bearbeitung');
$mech->content_contains('Test Test');

FixMyStreet::App->model('DB::Problem')->send_reports('zurich');
$email = $mech->get_email;
like $email->header('Subject'), qr/Feedback/, 'subject looks okay';
like $email->header('To'), qr/division\@example.org/, 'to line looks correct';
$mech->clear_emails_ok;

$report->discard_changes;
is $report->state, 'planned', 'Report now in planned state';

$mech->log_out_ok;
$user = $mech->log_in_ok( 'dm1@example.org') ;
$mech->get_ok( '/admin' );

$mech->content_contains( 'report_edit/' . $report->id );
$mech->content_contains( DateTime->now->strftime("%d.%m.%Y") );

# User confirms their email address
my $extra = $report->extra;
$extra->{email_confirmed} = 1;
$report->extra ( { %$extra } );
$report->update;

$mech->get_ok( '/admin/report_edit/' . $report->id );
$mech->content_lacks( 'Unbest&auml;tigt' ); # Confirmed email
$mech->submit_form_ok( { with_fields => { status_update => 'FINAL UPDATE' } } );
$mech->form_with_fields( 'status_update' );
$mech->submit_form_ok( { button => 'publish_response' } );

$mech->get_ok( '/report/' . $report->id );
$mech->content_contains('Beantwortet');
$mech->content_contains('Test Test');
$mech->content_contains('FINAL UPDATE');

$email = $mech->get_email;
like $email->header('To'), qr/test\@example.com/, 'to line looks correct';
like $email->header('From'), qr/division\@example.org/, 'from line looks correct';
like $email->body, qr/FINAL UPDATE/, 'body looks correct';
$mech->clear_emails_ok;

# Assign directly to planned, don't confirm email
@reports = $mech->create_problems_for_body( 1, 2, 'Second', {
    state              => 'unconfirmed',
    confirmed          => undef,
    cobrand            => 'zurich',
});
$report = $reports[0];

$mech->get_ok( '/admin/report_edit/' . $report->id );
$mech->submit_form_ok( { with_fields => { state => 'planned' } } );
$mech->get_ok( '/report/' . $report->id );
$mech->content_contains('In Bearbeitung');
$mech->content_contains('Second Test');

$mech->get_ok( '/admin/report_edit/' . $report->id );
$mech->content_contains( 'Unbest&auml;tigt' );
$mech->submit_form_ok( { button => 'publish_response', with_fields => { status_update => 'FINAL UPDATE' } } );

$mech->get_ok( '/report/' . $report->id );
$mech->content_contains('Beantwortet');
$mech->content_contains('Second Test');
$mech->content_contains('FINAL UPDATE');

$mech->email_count_is(0);

# Report assigned to third party

@reports = $mech->create_problems_for_body( 1, 2, 'Third', {
    state              => 'unconfirmed',
    confirmed          => undef,
    cobrand            => 'zurich',
});
$report = $reports[0];

$mech->get_ok( '/admin/report_edit/' . $report->id );
$mech->submit_form_ok( { with_fields => { body_external => 4 } } );
$mech->get_ok( '/report/' . $report->id );
$mech->content_contains('Beantwortet');
$mech->content_contains('Third Test');
$mech->content_contains('Wir haben Ihr Anliegen an External Body weitergeleitet');
FixMyStreet::App->model('DB::Problem')->send_reports('zurich');
$email = $mech->get_email;
like $email->header('Subject'), qr/Weitergeleitete Meldung/, 'subject looks okay';
like $email->header('To'), qr/external_body\@example.org/, 'to line looks correct';
like $email->body, qr/External Body/, 'body has right name';
unlike $email->body, qr/test\@example.com/, 'body does not contain email address';
$mech->clear_emails_ok;

# Test calling back, and third_personal boolean setting
$mech->get_ok( '/admin' );
is $mech->uri->path, '/admin', "am logged in";
$mech->content_contains( 'report_edit/' . $report->id );
$mech->get_ok( '/admin/report_edit/' . $report->id );
$mech->submit_form_ok( { with_fields => { state => 'unconfirmed' } } );
$mech->submit_form_ok( { with_fields => { body_external => 4, third_personal => 1 } } );
$mech->get_ok( '/report/' . $report->id );
$mech->content_contains('Beantwortet');
$mech->content_contains('Third Test');
$mech->content_contains('Wir haben Ihr Anliegen an External Body weitergeleitet');
FixMyStreet::App->model('DB::Problem')->send_reports('zurich');
$email = $mech->get_email;
like $email->header('Subject'), qr/Weitergeleitete Meldung/, 'subject looks okay';
like $email->header('To'), qr/external_body\@example.org/, 'to line looks correct';
like $email->body, qr/External Body/, 'body has right name';
like $email->body, qr/test\@example.com/, 'body does contain email address';
$mech->clear_emails_ok;
$mech->log_out_ok;

# Test only superuser can edit bodies
$user = $mech->log_in_ok( 'dm1@example.org') ;
$mech->get( '/admin/body/' . $zurich->id );
is $mech->res->code, 404, "only superuser should be able to edit bodies";
$mech->log_out_ok;

# Test only superuser can see "Add body" form
$user = $mech->log_in_ok( 'dm1@example.org') ;
$mech->get_ok( '/admin/bodies' );
$mech->content_lacks( '<form method="post" action="bodies"' );
$mech->log_out_ok;

$mech->delete_problems_for_body( 2 );
$mech->delete_user( 'dm1@example.org' );
$mech->delete_user( 'sdm1@example.org' );

ok $mech->host("www.fixmystreet.com"), "change host back";

done_testing();
