use strict;
use warnings;
use Test::More;

use FixMyStreet::TestMech;
use Web::Scraper;

my $mech = FixMyStreet::TestMech->new;

my $test_user = 'council_user@example.com';
my $test_pass = 'password';
my $test_council = 2651;
my $test_ward = 20723;

$mech->delete_user( $test_user );
my $user = FixMyStreet::App->model('DB::User')->create( {
    email => $test_user,
    password => $test_pass,
} );

my $p_user = FixMyStreet::App->model('DB::User')->find_or_create( {
    email => 'p_user@example.com'
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

$mech->content_contains( 'Summary Statistics for City of Edinburgh' );

FixMyStreet::App->model('DB::Contact')->search( { area_id => $test_council } )
  ->delete;

delete_problems();

my @cats = qw( Grafitti Litter Potholes );
for my $contact ( @cats ) {
    FixMyStreet::App->model('DB::Contact')->create(
        {
            area_id    => $test_council,
            category   => $contact,
            email      => "$contact\@example.org",
            confirmed  => 1,
            whenedited => DateTime->now,
            deleted    => 0,
            editor     => 'test',
            note       => 'test',
        }
    );
}

$mech->get_ok('/dashboard');

my $categories = scraper {
    process "select[name=category] > option", 'cats[]' => 'TEXT',
    process "select[name=ward] > option", 'wards[]' => 'TEXT',
    process "table[id=overview] > tr", 'rows[]' => scraper {
        process 'td', 'cols[]' => 'TEXT'
    },
    process "tr[id=total] > td", 'totals[]' => 'TEXT',
    process "tr[id=fixed_council] > td", 'council[]' => 'TEXT',
    process "tr[id=fixed_user] > td", 'user[]' => 'TEXT',
    process "tr[id=total_fixed] > td", 'total_fixed[]' => 'TEXT',
    process "tr[id=in_progress] > td", 'in_progress[]' => 'TEXT',
    process "tr[id=planned] > td", 'planned[]' => 'TEXT',
    process "tr[id=investigating] > td", 'investigating[]' => 'TEXT',
    process "tr[id=marked] > td", 'marked[]' => 'TEXT',
    process "tr[id=avg_marked] > td", 'avg_marked[]' => 'TEXT',
    process "tr[id=avg_fixed] > td", 'avg_fixed[]' => 'TEXT',
    process "tr[id=not_marked] > td", 'not_marked[]' => 'TEXT',
};

my $expected_cats = [ 'All', '-- Pick a category --', @cats, 'Other' ];
my $res = $categories->scrape( $mech->content );
is_deeply( $res->{cats}, $expected_cats, 'correct list of categories' );

foreach my $row ( @{ $res->{rows} }[1 .. 11] ) {
    foreach my $col ( @{ $row->{cols} } ) {
        is $col, 0;
    }
}


foreach my $test (
    {
        desc => 'confirmed today with no state',
        dt   => DateTime->now,
        counts => [1,1,1,1],
    },
    {
        desc => 'confirmed last 7 days with no state',
        dt   => DateTime->now->subtract( days => 6, hours => 23 ),
        counts => [1,2,2,2],
    },
    {
        desc => 'confirmed last 4 weeks with no state',
        dt   => DateTime->now->subtract( weeks => 2 ),
        counts => [1,2,3,3],
    },
    {
        desc => 'confirmed this year with no state',
        dt   => DateTime->now->subtract( weeks => 7 ),
        counts => [1,2,3,4],
    },
) {
    subtest $test->{desc} => sub {
        make_problem( { state => 'confirmed', conf_dt => $test->{dt} } );

        $mech->get_ok('/dashboard');
        $res = $categories->scrape( $mech->content );

        check_row( $res, 'totals', $test->{counts} );
        check_row( $res, 'not_marked', $test->{counts} );
    };
}

delete_problems();

foreach my $test (
    {
        desc => 'user fixed today',
        confirm_dt   => DateTime->now->subtract( days => 1 ),
        mark_dt      => DateTime->now,
        state => 'fixed - user',
        counts => {
            totals => [1,1,1,1],
            user => [1,1,1,1],
            council => [0,0,0,0],
            avg_fixed => [0,0,0,0],
            total_fixed => [1,1,1,1],
        }
    },
    {
        desc => 'council fixed today',
        confirm_dt   => DateTime->now->subtract( days => 1 ),
        mark_dt      => DateTime->now,
        state => 'fixed - council',
        counts => {
            totals => [2,2,2,2],
            user => [1,1,1,1],
            council => [1,1,1,1],
            avg_fixed => [1,1,1,1],
            total_fixed => [2,2,2,2],
        }
    },
    {
        desc => 'marked investigating today',
        confirm_dt   => DateTime->now->subtract( days => 1 ),
        mark_dt      => DateTime->now,
        state => 'investigating',
        counts => {
            totals => [3,3,3,3],
            user => [1,1,1,1],
            council => [1,1,1,1],
            total_fixed => [2,2,2,2],
            avg_marked => [1,1,1,1],
            investigating => [1,1,1,1],
        }
    },
) {
    subtest $test->{desc} => sub {
        make_problem(
            {
                state   => $test->{state},
                conf_dt => $test->{confirm_dt},
                mark_dt => $test->{mark_dt},
            }
        );

        $mech->get_ok('/dashboard');
        $res = $categories->scrape( $mech->content );

        foreach my $row ( keys %{ $test->{counts} } ) {
            check_row( $res, $row, $test->{counts}->{$row} );
        }
    };
}

sub make_problem {
    my $args = shift;

    my $p = FixMyStreet::App->model('DB::Problem')->create( {
        title => 'a problem',
        name => 'a user',
        anonymous => 1,
        detail => 'some detail',
        state => $args->{state},
        confirmed => $args->{conf_dt},
        whensent => $args->{conf_dt},
        lastupdate => $args->{mark_dt} || $args->{conf_dt},
        council => $test_council,
        postcode => 'EH99 1SP',
        latitude => '51',
        longitude => '1',
        areas      => $test_ward,
        used_map => 0,
        user_id => $p_user->id,
    } );

    if ( $args->{state} ne 'confirmed' ) {
        my $c = FixMyStreet::App->model('DB::Comment')->create( {
            problem => $p,
            user_id => $p_user->id,
            state => 'confirmed',
            problem_state => $args->{state},
            confirmed => $args->{mark_dt},
            text => 'an update',
            mark_fixed => $args->{state} =~ /fixed/ ? 1 : 0,
            anonymous => 1,
        } );
    }
}

sub check_row {
    my $res = shift;
    my $row = shift;
    my $totals = shift;

    is $res->{ $row }->[0], $totals->[0], "Correct count in $row for WTD";
    is $res->{ $row }->[1], $totals->[1], "Correct count in $row for last 7 days";
    is $res->{ $row }->[2], $totals->[2], "Correct count in $row for last 4 weeks";
    is $res->{ $row }->[3], $totals->[3], "Correct count in $row for YTD";
}

sub delete_problems {
    FixMyStreet::App->model('DB::Comment')
      ->search( { 'problem.council' => $test_council }, { join => 'problem' } )
      ->delete;
    FixMyStreet::App->model('DB::Problem')
      ->search( { council => $test_council } )->delete();
}

done_testing;
