use FixMyStreet::TestMech;
use FixMyStreet::DB;

my $mech = FixMyStreet::TestMech->new();

my @problems = $mech->create_problems_for_body(1, 2237, 'Title');
my $problem = $problems[0];
my $user = $problem->user;
my $user2 = $mech->create_user_ok('other@example.net');

is $user->active_planned_reports, 0;
is $user->planned_reports, 0;

$user->add_to_planned_reports($problem);
is $user->active_planned_reports, 1;
is $user->planned_reports, 1;
is $user->is_planned_report($problem), 1;

$user->add_to_planned_reports($problem);
is $user->active_planned_reports, 1;
is $user->planned_reports, 1;

$user->remove_from_planned_reports($problem);
is $user->active_planned_reports, 0;
is $user->planned_reports, 1;
$user->discard_changes;
is $user->is_planned_report($problem), 0;

$user->add_to_planned_reports($problem);
is $user->active_planned_reports, 1;
is $user->planned_reports, 2;
$user->discard_changes;
is $user->is_planned_report($problem), 1;

$user2->add_to_planned_reports($problem);
is $user->active_planned_reports, 0;
is $user->planned_reports, 2;
is $user2->active_planned_reports, 1;
is $user2->planned_reports, 1;

$user->add_to_planned_reports($problem);
is $user->active_planned_reports, 1;
is $user->planned_reports, 3;
is $user2->active_planned_reports, 0;
is $user2->planned_reports, 1;

done_testing();
