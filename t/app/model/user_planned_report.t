use strict;
use warnings;

use Test::More;

use FixMyStreet::TestMech;
use FixMyStreet::DB;

my $mech = FixMyStreet::TestMech->new();

my @problems = $mech->create_problems_for_body(1, 2237, 'Title');
my $problem = $problems[0];
my $user = $problem->user;

is $user->active_planned_reports, 0;
is $user->planned_reports, 0;

$user->add_to_planned_reports($problem);
is $user->active_planned_reports, 1;
is $user->planned_reports, 1;

$user->remove_from_planned_reports($problem);
is $user->active_planned_reports, 0;
is $user->planned_reports, 1;

$user->add_to_planned_reports($problem);
is $user->active_planned_reports, 1;
is $user->planned_reports, 2;

done_testing();

END {
    $mech->delete_user($user);
}
