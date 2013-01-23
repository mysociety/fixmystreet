# TODO
# Report to third party (with third_personal)
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
my $division = $mech->create_body_ok( 2, 'Division 1' );
$division->parent( $zurich->id );
$division->update;
my $subdivision = $mech->create_body_ok( 3, 'Subdivision A' );
$subdivision->parent( $division->id );
$subdivision->update;

my @reports = $mech->create_problems_for_body( 1, 2, 'Test', {
    state              => 'unconfirmed',
    confirmed          => undef,
    cobrand            => 'zurich',
});
my $report = $reports[0];

$mech->get_ok( '/report/' . $report->id );
$mech->content_contains('moderation');

# Check logging in to deal with this report
$mech->get_ok( '/admin' );
is $mech->uri->path, '/auth', "got sent to the sign in page";

my $user = $mech->log_in_ok( 'dm1@example.org') ;
$mech->get_ok( '/admin' );
is $mech->uri->path, '/auth', "got sent to the sign in page";
$user->from_body( 2 );
$user->update;

$mech->get_ok( '/admin' );
is $mech->uri->path, '/admin', "am logged in";

$mech->content_contains( 'report_edit/' . $report->id );
$mech->content_contains( DateTime->now->strftime("%d.%m.%Y") );
$mech->content_contains( 'Erfasst' );

$mech->get_ok( '/admin/report_edit/' . $report->id );
$mech->submit_form_ok( { with_fields => { state => 'confirmed' } } );
$mech->get_ok( '/report/' . $report->id );
$mech->content_contains('Aufgenommen');
$mech->content_contains('Test Test');
$mech->content_lacks('photo/' . $report->id . '.jpeg');

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
$mech->content_contains( 'originally entered: &ldquo;Test Test 1 for 2 Detail&rdquo;' );

$mech->get_ok( '/admin/report_edit/' . $report->id );
$mech->submit_form_ok( { with_fields => { body_subdivision => 3 } } );

$mech->get_ok( '/report/' . $report->id );
$mech->content_contains('In Bearbeitung');
$mech->content_contains('Test Test');

$mech->log_out_ok;

$user = $mech->log_in_ok( 'sdm1@example.org') ;
$mech->get_ok( '/admin' );
is $mech->uri->path, '/auth', "got sent to the sign in page";
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

$report->discard_changes;
is $report->state, 'planned', 'Report now in planned state';

$mech->log_out_ok;
$user = $mech->log_in_ok( 'dm1@example.org') ;
$mech->get_ok( '/admin' );

$mech->content_contains( 'report_edit/' . $report->id );
$mech->content_contains( DateTime->now->strftime("%d.%m.%Y") );

$mech->get_ok( '/admin/report_edit/' . $report->id );
$mech->submit_form_ok( { with_fields => { status_update => 'FINAL UPDATE' } } );
$mech->form_with_fields( 'status_update' );
$mech->submit_form_ok( { button => 'publish_response' } );

$mech->get_ok( '/report/' . $report->id );
$mech->content_contains('Erledigt');
$mech->content_contains('Test Test');
$mech->content_contains('FINAL UPDATE');

$mech->delete_problems_for_body( 2 );
$mech->delete_user( 'dm1@example.org' );
$mech->delete_user( 'sdm1@example.org' );

ok $mech->host("www.fixmystreet.com"), "change host back";

done_testing();
