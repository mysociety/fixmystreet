use strict;
use warnings;
use Test::More;

use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

# Create test data
my $user = $mech->create_user_ok( 'bromley@example.com' );
my $body = $mech->create_body_ok( 2482, 'Bromley' );

my @reports = $mech->create_problems_for_body( 1, 2482, 'Test', {
    cobrand => 'bromley',
    user => $user,
});
my $report = $reports[0];

for my $update ('in progress', 'unable to fix') {
    FixMyStreet::App->model('DB::Comment')->find_or_create( {
        problem_state => $update,
        problem_id => $report->id,
        user_id    => $user->id,
        name       => 'User',
        mark_fixed => 'f',
        text       => "This update marks it as $update",
        state      => 'confirmed',
        confirmed  => 'now()',
        anonymous  => 'f',
    } );
}

# Test Bromley special casing of 'unable to fix'
$mech->get_ok( '/report/' . $report->id );
$mech->content_contains( 'marks it as in progress' );
$mech->content_contains( 'marked as in progress' );
$mech->content_contains( 'marks it as unable to fix' );
$mech->content_contains( 'marked as no further action' );

# Clean up
$mech->delete_user($user);
$mech->delete_problems_for_body( 2482 );
done_testing();
