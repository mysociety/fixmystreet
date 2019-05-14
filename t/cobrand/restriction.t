use strict;
use warnings;

package FixMyStreet::Cobrand::Tester;

use parent 'FixMyStreet::Cobrand::Default';

sub problems_restriction {
    my ($self, $rs) = @_;
    return $rs->search({ cobrand => 'tester' });
}

sub updates_restriction {
    my ($self, $rs) = @_;
    return $rs->search({ 'problem.cobrand' => 'tester' }, { join => 'problem' });
}

package main;

use FixMyStreet::TestMech;

use Catalyst::Test 'FixMyStreet::App';

my ($res, $c) = ctx_request('/');

my $cobrand = FixMyStreet::Cobrand::Tester->new({c => $c});
$c->stash->{cobrand} = $cobrand;

my $mech = FixMyStreet::TestMech->new;

my ($prob1) = $mech->create_problems_for_body(1, 1234, 'Title');
my ($prob2) = $mech->create_problems_for_body(1, 1234, 'Title', { cobrand => 'tester' });
$mech->create_problems_for_body(1, 1234, 'Title', { latitude => 0, longitude => 0 });
$mech->create_problems_for_body(1, 1234, 'Title', { cobrand => 'tester', latitude => 0, longitude => 0 });

for (1..2) {
    $c->model('DB::Comment')->create({
        problem_id => $_ == 1 ? $prob1->id : $prob2->id,
        user_id => $prob2->user_id,
        name => 'User',
        mark_fixed => 'false',
        text => 'This is some update text',
        state => 'confirmed',
        cobrand => 'tester',
        anonymous => 'f',
    });
}

is($c->model('DB::Problem')->count, 4, 'Four reports in database');
is($cobrand->problems->count, 2, 'Two reports in the right cobrand');
is($cobrand->updates->count, 1, 'One update in the right cobrand');

my $nearby = $c->model('DB::Nearby')->nearby($c, distance => 5, ids => [], limit => 10, latitude => 0.003, longitude => 0.004);
is(@$nearby, 1, 'One report close to the origin point');

done_testing();
