use strict;
use warnings;

use Test::More;

use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

$mech->get_ok('/my/planned');
is $mech->uri->path, '/auth', "got sent to the sign in page";

my $body = $mech->create_body_ok(2237, 'Oxfordshire');
my ($problem) = $mech->create_problems_for_body(1, $body->id, 'Test Title');

$mech->get_ok($problem->url);
$mech->content_lacks('Shortlist');
$mech->content_lacks('Shortlisted');

my $user = $mech->log_in_ok( 'test@example.com' );
$user->update({ from_body => $body });
$user->user_body_permissions->find_or_create({
    body => $body,
    permission_type => 'planned_reports',
});

$mech->get_ok('/my/planned');
$mech->content_lacks('Test Title');

$user->add_to_planned_reports($problem);
$mech->get_ok('/my/planned');
$mech->content_contains('Test Title');

$user->remove_from_planned_reports($problem);
$mech->get_ok('/my/planned');
$mech->content_lacks('Test Title');

$user->add_to_planned_reports($problem);
$mech->get_ok('/my/planned');
$mech->content_contains('Test Title');

$mech->get_ok($problem->url);
$mech->content_contains('Shortlisted');
$mech->submit_form_ok({ with_fields => { 'shortlist-remove' => 1 } });
$mech->content_contains('Shortlist');
$mech->submit_form_ok({ with_fields => { 'shortlist-add' => 1 } });
$mech->content_contains('Shortlisted');

$mech->get_ok('/my/planned?sort=shortlist&ajax=1');
$mech->content_contains('shortlist-up');
$mech->content_contains('shortlist-down');

$mech->get_ok('/my/planned?sort=created-desc&ajax=1');
$mech->content_lacks('shortlist-up');
$mech->content_lacks('shortlist-down');

$mech->get_ok('/my/planned?ajax=1');
$mech->content_contains('shortlist-up');
$mech->content_contains('shortlist-down');

done_testing();

END {
    $mech->delete_user($user);
}
