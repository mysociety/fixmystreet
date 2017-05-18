use strict;
use warnings;
use Test::More;

use FixMyStreet::App;
use FixMyStreet::TestMech;
use JSON::MaybeXS;

my $mech = FixMyStreet::TestMech->new;
my $oxfordshire = $mech->create_body_ok(2237, 'Oxfordshire County Council', { id => 2237 });

my $user = $mech->log_in_ok( 'test@example.com' );
$user->update({ from_body => $oxfordshire });
$user->user_body_permissions->find_or_create({
    body => $oxfordshire,
    permission_type => 'planned_reports',
});

my $area_id = '123';

my ($problem1) = $mech->create_problems_for_body(1, $oxfordshire->id, 'Title', { areas => ",$area_id,6753,4324,", whensent => \'current_timestamp' });
my ($problem2) = $mech->create_problems_for_body(1, $oxfordshire->id, 'Title', { areas => ",6753,$area_id,4324,", whensent => \'current_timestamp' });
my ($problem3) = $mech->create_problems_for_body(1, $oxfordshire->id, 'Title', { areas => ",$area_id,6753,4324,", whensent => \"current_timestamp-'60 days'::interval" });
my ($problem4) = $mech->create_problems_for_body(1, $oxfordshire->id, 'Title', { areas => ",6753,4324,", whensent => \'current_timestamp' });

subtest 'in_area returns correct number of problems in a given area' => sub {
    my $in_area = FixMyStreet::DB->resultset('Problem')->in_area($area_id);

    is $in_area->count, 3, 'correct count is returned';

    $in_area = FixMyStreet::DB->resultset('Problem')->in_area($area_id, DateTime->now->subtract(days => 30));

    is $in_area->count, 2, 'allows filtering by date';
};

subtest 'planned_in_area gets planned reports' => sub {
    $user->add_to_planned_reports($problem1);
    $user->add_to_planned_reports($problem2);

    $problem2->user_planned_reports->first->update({
        added => \"current_timestamp-'60 days'::interval"
    });

    my $planned_in_area = FixMyStreet::DB->resultset('Problem')->planned_in_area($area_id);

    is $planned_in_area->count, 2, 'correct count is returned';

    $planned_in_area = FixMyStreet::DB->resultset('Problem')->planned_in_area($area_id, DateTime->now->subtract(days => 30));

    is $planned_in_area->count, 1, 'allows filtering by date';
};

subtest 'fixed_in_area gets fixed reports' => sub {
    $mech->create_comment_for_problem($problem1, $user, 'Title', 'text', 0, 'confirmed', undef, { created => DateTime->now->subtract(days => 32) });
    $problem1->update({ state => 'fixed - council', created => DateTime->now->subtract(days => 40) });
    $mech->create_comment_for_problem($problem1, $user, 'Title', 'text', 0, 'confirmed', 'fixed - council', { created => DateTime->now->subtract(days => 10) });

    $problem2->update({ state => 'fixed', created => DateTime->now->subtract(days => 60) });
    $mech->create_comment_for_problem($problem2, $user, 'Title', 'text', 0, 'confirmed', 'fixed', { created => DateTime->now->subtract(days => 32) });

    $problem3->update({ state => 'fixed - user', created => DateTime->now->subtract(days => 60) });
    $mech->create_comment_for_problem($problem3, $user, 'Title', 'text', 0, 'confirmed', 'fixed - user', { created => DateTime->now->subtract(days => 60) });

    my $fixed_in_area = FixMyStreet::DB->resultset('Problem')->fixed_in_area($area_id);

    is $fixed_in_area->count, 3, 'correct count is returned';

    $fixed_in_area = FixMyStreet::DB->resultset('Problem')->fixed_in_area($area_id, DateTime->now->subtract(days => 30));

    is $fixed_in_area->count, 1, 'allows filtering by date';
};

END {
    $mech->delete_user($user);
    $mech->delete_body($oxfordshire);
    done_testing();
}
