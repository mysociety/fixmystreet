use strict;
use warnings;

use FixMyStreet;
BEGIN { FixMyStreet->test_mode(1); }

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

my $now = DateTime->now( time_zone => FixMyStreet->local_time_zone );
subtest 'testing report_age' => sub {
    # Delete all previous reports
    my @reports = FixMyStreet::DB->resultset('Problem')->all;
    for my $r (@reports) {
        $r->comments->delete;
        $r->questionnaires->delete;
        $r->delete;
    }

    my $around_map_body = FixMyStreet::DB->resultset('Body')
        ->create( { name => 'Around Map Council' } );

    # Set some problems
    my @problem_params = (
        {   title => 'open_less_month',
            state => 'confirmed',
            dt    => $now->clone->subtract( days => 14 ),
        },
        {   title => 'open_more_month',
            state => 'confirmed',
            dt    => $now->clone->subtract( months => 2 ),
        },

        {   title => 'closed_less_week',
            state => 'not responsible',
            dt    => $now->clone->subtract( days => 6 ),
        },
        {   title => 'closed_more_week',
            state => 'not responsible',
            dt    => $now->clone->subtract( weeks => 2 ),
        },

        {   title => 'fixed_less_day',
            state => 'fixed - council',
            dt    => $now->clone->subtract( hours => 23 ),
        },
        {   title => 'fixed_more_day',
            state => 'fixed - council',
            dt    => $now->clone->subtract( days => 2 ),
        },

        {   title      => 'open_less_month_non_public',
            state      => 'confirmed',
            non_public => 1,
            dt         => $now->clone->subtract( days => 14 ),
        },
        {   title      => 'open_more_month_non_public',
            state      => 'confirmed',
            non_public => 1,
            dt         => $now->clone->subtract( months => 2 ),
        },
    );
    for (@problem_params) {
        $mech->create_problems_for_body( 1, $around_map_body->id, $_->{title},
            { %$_, cobrand => 'tester', latitude => 0, longitude => 0 },
        );
    }

    # Defaults
    my %search_params = (
        distance  => 5,
        latitude  => 0.003,
        longitude => 0.004,
    );
    $c->stash->{report_age_field} = 'confirmed';

    subtest 'scalar report_age' => sub {
        my $got = $c->model('DB::Nearby')->nearby(
            $c,
            %search_params,
            report_age => '1 weeks',
        );

        my @got_titles = sort map { $_->problem->title } @$got;
        my @expected_titles = sort qw/
            closed_less_week
            fixed_less_day
            fixed_more_day
            /;
        is_deeply \@got_titles, \@expected_titles;
    };

    subtest 'hashref report_age' => sub {
        my $got = $c->model('DB::Nearby')->nearby(
            $c,
            %search_params,
            report_age => {
                open   => '1 months',
                closed => '1 weeks',
                fixed  => '1 days',
            },
        );

        my @got_titles = sort map { $_->problem->title } @$got;
        my @expected_titles = sort qw/
            open_less_month
            closed_less_week
            fixed_less_day
            /;
        is_deeply \@got_titles, \@expected_titles;
    };

    subtest 'hashref report_age interacting with non_public_if_possible' => sub {
        # Set a report_inspect user on $c
        my $report_inspect_user = $mech->log_in_ok( 'report_inspect@example.com' );
        $report_inspect_user->update({ from_body => $around_map_body });
        $report_inspect_user->user_body_permissions->find_or_create({
            body => $around_map_body,
            permission_type => 'report_inspect',
        });
        $c->user($report_inspect_user);

        subtest 'only_non_public = 1' => sub {
            $c->stash->{only_non_public} = 1;

            subtest 'without report_age' => sub {
                my $got = $c->model('DB::Nearby')->nearby(
                    $c,
                    %search_params,
                );

                my @got_titles = sort map { $_->problem->title } @$got;
                my @expected_titles = sort qw/
                    open_less_month_non_public
                    open_more_month_non_public
                    /;
                is_deeply \@got_titles, \@expected_titles;
            };

            subtest 'with report_age' => sub {
                my $got = $c->model('DB::Nearby')->nearby(
                    $c,
                    %search_params,
                    report_age => {
                        open => '1 months',
                    },
                );

                my @got_titles = sort map { $_->problem->title } @$got;
                my @expected_titles = sort qw/
                    open_less_month_non_public
                    /;
                is_deeply \@got_titles, \@expected_titles;
            };
        };

        subtest 'only_non_public = 0' => sub {
            $c->stash->{only_non_public} = 0;

            subtest 'without report_age' => sub {
                my $got = $c->model('DB::Nearby')->nearby(
                    $c,
                    %search_params,
                );

                my @got_titles = sort map { $_->problem->title } @$got;
                my @expected_titles = sort qw/
                    open_less_month_non_public
                    open_more_month_non_public
                    open_less_month
                    open_more_month
                    closed_less_week
                    closed_more_week
                    fixed_less_day
                    fixed_more_day
                    /;
                is_deeply \@got_titles, \@expected_titles;
            };

            subtest 'with report_age' => sub {
                my $got = $c->model('DB::Nearby')->nearby(
                    $c,
                    %search_params,
                    report_age => {
                        open => '1 months',
                    },
                );

                my @got_titles = sort map { $_->problem->title } @$got;
                my @expected_titles = sort qw/
                    open_less_month_non_public
                    open_less_month
                    closed_less_week
                    closed_more_week
                    fixed_less_day
                    fixed_more_day
                    /;
                is_deeply \@got_titles, \@expected_titles;
            };
        };
    };
};

done_testing();
