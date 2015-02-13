use strict;
use warnings;
use Test::More;

use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

# Create test data
my $user = $mech->create_user_ok( 'bromley@example.com' );
my $body = $mech->create_body_ok( 2482, 'Bromley', id => 2482 );
$mech->create_contact_ok(
    body_id => $body->id,
    category => 'Other',
    email => 'LIGHT',
);

my @reports = $mech->create_problems_for_body( 1, $body->id, 'Test', {
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

subtest 'testing special Open311 behaviour', sub {
    $report->set_extra_fields();
    $report->update;
    $body->update( { send_method => 'Open311', endpoint => 'http://bromley.endpoint.example.com', jurisdiction => 'FMS', api_key => 'test' } );
    FixMyStreet::override_config {
        SEND_REPORTS_ON_STAGING => 1,
    }, sub {
        FixMyStreet::App->model('DB::Problem')->send_reports();
    };
    $report->discard_changes;
    ok $report->whensent, 'Report marked as sent';
    is $report->send_method_used, 'Open311', 'Report sent via Open311';
    is $report->external_id, 248, 'Report has right external ID';
};

# Clean up
$mech->delete_user($user);
$mech->delete_problems_for_body( $body->id );
done_testing();
