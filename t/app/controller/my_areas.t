use strict;
use warnings;

use Test::More;

use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

$mech->get_ok('/my/areas');
is $mech->uri->path, '/auth', "got sent to the sign in page";

my $body = $mech->create_body_ok(2237, 'Oxfordshire');

my $user = $mech->log_in_ok( 'testwithareas@example.com' );
my $categories = [
    $mech->create_contact_ok( body_id => $body->id, category => 'Cows', email => 'cows@example.net' )->id,
    $mech->create_contact_ok( body_id => $body->id, category => 'Potholes', email => 'potholes@example.net' )->id,
];
$mech->create_contact_ok( body_id => $body->id, category => 'Tapirs', email => 'tapirs@example.net' )->id,
$user->from_body($body);
$user->set_extra_metadata('categories', $categories);
$user->update({areas => ',123,456,789'});

my ($problem1) = $mech->create_problems_for_body(1, '2504', 'First Problem', { areas => ',123,6753,4324,', category => 'Cows' });
my ($problem2) = $mech->create_problems_for_body(1, '2504', 'Second Problem', { areas => ',6753,456,4324,', category => 'Cows' });
my ($problem3) = $mech->create_problems_for_body(1, '2504', 'Third Problem', { areas => ',6753,3433,789,', category => 'Potholes' });
my ($problem4) = $mech->create_problems_for_body(1, '2504', 'Fourth Problem', { areas => ',6753,3433,32324,', category => 'Cows' });
$mech->create_problems_for_body(1, '2504', 'Tapirs', { areas => ',123,3433,32324,', category => 'Tapirs' });

$mech->get_ok('/my/areas');
is $mech->uri->path, '/my/areas', 'path is correct';

$mech->content_contains('First Problem');
$mech->content_contains('Second Problem');
$mech->content_contains('Third Problem');
$mech->content_lacks('Fourth Problem');

$mech->content_contains('<option value="Cows" selected>');
$mech->content_contains('<option value="Potholes" selected>');
$mech->content_lacks('<option value="Tapirs" selected>');

$mech->get_ok('/my/areas?filter_category=Cows,Tapirs');

$mech->content_contains('<option value="Cows" selected>');
$mech->content_contains('<option value="Tapirs" selected>');
$mech->content_lacks('<option value="Potholes" selected>');

my $user2 = $mech->log_in_ok( 'testwithoutareas@example.com' );
$mech->get('/my/areas');
is $mech->res->code, 404, "User without assigned areas can't access /my/areas";

done_testing();

END {
    $mech->delete_user($user2);
    $mech->delete_user($user);
    $mech->delete_body($body);
}
