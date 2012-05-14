use strict;
use warnings;
use Test::More;

use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

my $test_user = 'council_user@example.com';
my $test_pass = 'password';
my $test_council = 2651;

$mech->delete_user( $test_user );
my $user = FixMyStreet::App->model('DB::User')->create( {
    email => $test_user,
    password => $test_pass,
} );

$mech->not_logged_in_ok;
$mech->get_ok('/dashboard');

$mech->content_contains( 'sign in' );

$mech->submit_form(
    with_fields => { email => $test_user, password_sign_in => $test_pass }
);

is $mech->status, '404', 'If not council user get 404';

$user->from_council( $test_council );
$user->update;

$mech->log_out_ok;
$mech->get_ok('/dashboard');
$mech->submit_form_ok( {
    with_fields => { email => $test_user, password_sign_in => $test_pass }
} );

$mech->content_contains( 'Summary Statistics' );
$mech->content_contains( 'Edinburgh' );

done_testing;
