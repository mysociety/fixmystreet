use Test::MockTime ':all';

use FixMyStreet::TestMech;
use Web::Scraper;

my $mech = FixMyStreet::TestMech->new;

my $test_user = 'council_user@example.com';
my $test_pass = 'password';
my $test_council = 2651;
my $test_ward = 20723;

my $body = $mech->create_body_ok($test_council, 'City of Edinburgh Council');

$mech->delete_user( $test_user );
my $user = $mech->create_user_ok($test_user, password => $test_pass);

my $p_user = $mech->create_user_ok('p_user@example.com');

# Dashboard tests assume we are not too early in year, to allow reporting
# within same year, as a convenience.
set_absolute_time('2014-03-01T12:00:00');
FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ { fixmystreet => '.' } ],
    MAPIT_URL => 'http://mapit.uk/',
}, sub {

    $mech->not_logged_in_ok;
    $mech->get_ok('/dashboard');

    $mech->content_contains( 'sign in' );

    $mech->submit_form(
        with_fields => { email => $test_user, password_sign_in => $test_pass }
    );

    is $mech->status, '404', 'If not council user get 404';

    $user->from_body( $body->id );
    $user->update;

    $mech->log_out_ok;
    $mech->get_ok('/dashboard');
    $mech->submit_form_ok( {
        with_fields => { email => $test_user, password_sign_in => $test_pass }
    } );

    $mech->content_contains( 'Area 2651' );

    FixMyStreet::App->model('DB::Contact')->search( { body_id => $body->id } )
      ->delete;

    delete_problems();

    my @cats = qw( Grafitti Litter Potholes Other );
    for my $contact ( @cats ) {
        FixMyStreet::App->model('DB::Contact')->create(
            {
                body_id    => $body->id,
                category   => $contact,
                email      => "$contact\@example.org",
                state => 'confirmed',
                whenedited => DateTime->now,
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
        process "tr[id=action_scheduled] > td", 'action_scheduled[]' => 'TEXT',
        process "tr[id=investigating] > td", 'investigating[]' => 'TEXT',
        process "tr[id=marked] > td", 'marked[]' => 'TEXT',
        process "tr[id=avg_marked] > td", 'avg_marked[]' => 'TEXT',
        process "tr[id=avg_fixed] > td", 'avg_fixed[]' => 'TEXT',
        process "tr[id=not_marked] > td", 'not_marked[]' => 'TEXT',
        process "tr[id=closed] > td", 'closed[]' => 'TEXT',
        process "table[id=reports] > tr > td", 'report_lists[]' => scraper {
            process 'ul > li', 'reports[]' => 'TEXT'
        },
    };

    my $expected_cats = [ 'All', '-- Pick a category --', @cats ];
    my $res = $categories->scrape( $mech->content );
    is_deeply( $res->{cats}, $expected_cats, 'correct list of categories' );

    foreach my $row ( @{ $res->{rows} }[1 .. 11] ) {
        foreach my $col ( @{ $row->{cols} } ) {
            is $col, 0;
        }
    }

    for my $reports ( @{ $res->{report_lists} } ) {
        is_deeply $reports, {}, 'No reports';
    }

    my $now = DateTime->now(time_zone => 'local');
    foreach my $test (
        {
            desc => 'confirmed today with no state',
            dt   => $now,
            counts => [1,1,1,1],
            report_counts => [1, 0, 0],
        },
        {
            desc => 'confirmed last 7 days with no state',
            dt   => $now->clone->subtract( days => 6, hours => 23 ),
            counts => [1,2,2,2],
            report_counts => [2, 0, 0],
        },
        {
            desc => 'confirmed last 8 days with no state',
            dt   => $now->clone->subtract( days => 8 ),
            counts => [1,2,3,3],
            report_counts => [2, 1, 0],
        },
        {
            desc => 'confirmed last 2 weeks with no state',
            dt   => $now->clone->subtract( weeks => 2, hours => 1 ),
            counts => [1,2,4,4],
            report_counts => [2, 1, 1],
        },
        {
            desc => 'confirmed this year with no state',
            dt   => $now->clone->subtract( weeks => 7 ),
            counts => [1,2,4,5],
            report_counts => [2, 1, 1],
        },
    ) {
        subtest $test->{desc} => sub {
            make_problem( { state => 'confirmed', conf_dt => $test->{dt} } );

            $mech->get_ok('/dashboard');
            $res = $categories->scrape( $mech->content );

            check_row( $res, 'totals', $test->{counts} );
            check_row( $res, 'not_marked', $test->{counts} );

            check_report_counts( $res, $test->{report_counts} );
        };
    }

    delete_problems();

    my $is_monday = DateTime->now->day_of_week == 1 ? 1 : 0;

    foreach my $test (
        {
            desc => 'user fixed today',
            confirm_dt   => DateTime->now->subtract( days => 1 ),
            mark_dt      => DateTime->now,
            state => 'fixed - user',
            counts => {
                totals => $is_monday ? [0,1,1,1] : [1,1,1,1],
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
                totals => $is_monday ? [0,2,2,2] : [2,2,2,2],
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
                totals => $is_monday ? [0,3,3,3] : [3,3,3,3],
                user => [1,1,1,1],
                council => [1,1,1,1],
                total_fixed => [2,2,2,2],
                avg_marked => [1,1,1,1],
                investigating => [1,1,1,1],
                marked => [1,1,1,1]
            }
        },
        {
            desc => 'marked in progress today',
            confirm_dt   => DateTime->now->subtract( days => 1 ),
            mark_dt      => DateTime->now,
            state => 'in progress',
            counts => {
                totals => $is_monday ? [0,4,4,4] : [4,4,4,4],
                user => [1,1,1,1],
                council => [1,1,1,1],
                total_fixed => [2,2,2,2],
                avg_marked => [1,1,1,1],
                investigating => [1,1,1,1],
                in_progress => [1,1,1,1],
                marked => [2,2,2,2]
            }
        },
        {
            desc => 'marked as action scheduled today',
            confirm_dt   => DateTime->now->subtract( days => 1 ),
            mark_dt      => DateTime->now,
            state => 'action scheduled',
            counts => {
                totals => $is_monday ? [ 0,5,5,5] : [5,5,5,5],
                user => [1,1,1,1],
                council => [1,1,1,1],
                total_fixed => [2,2,2,2],
                avg_marked => [1,1,1,1],
                investigating => [1,1,1,1],
                in_progress => [1,1,1,1],
                action_scheduled => [1,1,1,1],
                marked => [3,3,3,3]
            }
        },
        {
            desc => 'marked as action scheduled today, confirmed a week ago',
            confirm_dt   => DateTime->now->subtract( days => 8 ),
            mark_dt      => DateTime->now,
            state => 'action scheduled',
            counts => {
                totals => $is_monday ? [0,5,6,6] : [5,5,6,6],
                user => [1,1,1,1],
                council => [1,1,1,1],
                total_fixed => [2,2,2,2],
                avg_marked => [3,3,3,3],
                investigating => [1,1,1,1],
                in_progress => [1,1,1,1],
                action_scheduled => [2,2,2,2],
                marked => [4,4,4,4]
            }
        },
        {
            desc => 'marked as council fixed today, confirmed a week ago',
            confirm_dt   => DateTime->now->subtract( days => 8 ),
            mark_dt      => DateTime->now,
            state => 'fixed - council',
            counts => {
                totals => $is_monday ? [0,5,7,7] : [5,5,7,7],
                user => [1,1,1,1],
                council => [2,2,2,2],
                total_fixed => [3,3,3,3],
                avg_fixed => [5,5,5,5],
                avg_marked => [3,3,3,3],
                investigating => [1,1,1,1],
                in_progress => [1,1,1,1],
                action_scheduled => [2,2,2,2],
                marked => [4,4,4,4]
            }
        },
        {
            desc => 'marked as council fixed a week ago, confirmed 3 weeks ago',
            confirm_dt   => DateTime->now->subtract( days => 21),
            mark_dt      => DateTime->now->subtract( days => 8 ),
            state => 'fixed - council',
            counts => {
                totals => $is_monday ? [0,5,8,8] : [5,5,8,8],
                user => [1,1,1,1],
                council => [2,2,3,3],
                total_fixed => [3,3,4,4],
                avg_fixed => [5,5,7,7],
                avg_marked => [3,3,3,3],
                investigating => [1,1,1,1],
                in_progress => [1,1,1,1],
                action_scheduled => [2,2,2,2],
                marked => [4,4,4,4]
            }
        },
        {
            desc => 'marked as user fixed 6 weeks ago, confirmed 7 weeks ago',
            confirm_dt   => DateTime->now->subtract( weeks => 6 ),
            mark_dt      => DateTime->now->subtract( weeks => 7 ),
            state => 'fixed - user',
            counts => {
                totals => $is_monday ? [0,5,8,9] : [5,5,8,9],
                user => [1,1,1,2],
                council => [2,2,3,3],
                total_fixed => [3,3,4,5],
                avg_fixed => [5,5,7,7],
                avg_marked => [3,3,3,3],
                investigating => [1,1,1,1],
                in_progress => [1,1,1,1],
                action_scheduled => [2,2,2,2],
                marked => [4,4,4,4]
            }
        },
        {
            desc => 'marked as closed',
            confirm_dt   => DateTime->now->subtract( days => 1 ),
            mark_dt      => DateTime->now,
            state => 'closed',
            counts => {
                totals => $is_monday ? [0,6,9,10] : [6,6,9,10],
                user => [1,1,1,2],
                council => [2,2,3,3],
                total_fixed => [3,3,4,5],
                avg_fixed => [5,5,7,7],
                avg_marked => [2,2,2,2],
                investigating => [1,1,1,1],
                in_progress => [1,1,1,1],
                action_scheduled => [2,2,2,2],
                closed => [1,1,1,1],
                marked => [5,5,5,5]
            }
        },
        {
            desc => 'marked as planned',
            confirm_dt   => DateTime->now->subtract( days => 1 ),
            mark_dt      => DateTime->now,
            state => 'planned',
            counts => {
                totals => $is_monday ? [0,7,10,11] : [7,7,10,11],
                user => [1,1,1,2],
                council => [2,2,3,3],
                total_fixed => [3,3,4,5],
                avg_fixed => [5,5,7,7],
                avg_marked => [2,2,2,2],
                investigating => [1,1,1,1],
                in_progress => [1,1,1,1],
                action_scheduled => [3,3,3,3],
                closed => [1,1,1,1],
                marked => [6,6,6,6]
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

    delete_problems();

    for my $test (
        {
            desc => 'Selecting no category does nothing',
            p1 => {
                    state   => 'confirmed',
                    conf_dt => DateTime->now(),
                    category => 'Potholes',
            },
            p2 => {
                    state   => 'confirmed',
                    conf_dt => DateTime->now(),
                    category => 'Litter',
            },
            category => '',
            counts => {
                totals => [2,2,2,2],
            },
            counts_after => {
                totals => [2,2,2,2],
            },
            report_counts => [2,0,0],
            report_counts_after => [2,0,0],
        },
        {
            desc => 'Limit display by category',
            category => 'Potholes',
            counts => {
                totals => [2,2,2,2],
            },
            counts_after => {
                totals => [1,1,1,1],
            },
            report_counts => [2,0,0],
            report_counts_after => [1,0,0],
        },
        {
            desc => 'Limit display for category with no entries',
            category => 'Grafitti',
            counts => {
                totals => [2,2,2,2],
            },
            counts_after => {
                totals => [0,0,0,0],
            },
            report_counts => [2,0,0],
            report_counts_after => [0,0,0],
        },
        {
            desc => 'Limit display by category for council fixed',
            p1 => {
                    state   => 'fixed - council',
                    conf_dt => DateTime->now()->subtract( weeks => 1 ),
                    mark_dt => DateTime->now()->subtract( weeks => 1 ),
                    category => 'Potholes',
            },
            p2 => {
                    state   => 'fixed - council',
                    conf_dt => DateTime->now()->subtract( weeks => 1 ),
                    mark_dt => DateTime->now()->subtract( weeks => 1 ),
                    category => 'Litter',
            },
            category => 'Potholes',
            counts => {
                council => [0,0,2,2],
                totals => [2,2,4,4],
            },
            counts_after => {
                council => [0,0,1,1],
                totals => [1,1,2,2],
            },
            report_counts => [2,2,0],
            report_counts_after => [1,1,0],
        },
        {
            desc => 'Limit display by category for user fixed',
            p1 => {
                    state   => 'fixed - user',
                    conf_dt => DateTime->now()->subtract( weeks => 1 ),
                    mark_dt => DateTime->now()->subtract( weeks => 1 ),
                    category => 'Potholes',
            },
            p2 => {
                    state   => 'fixed - user',
                    conf_dt => DateTime->now()->subtract( weeks => 1 ),
                    mark_dt => DateTime->now()->subtract( weeks => 1 ),
                    category => 'Litter',
            },
            category => 'Potholes',
            counts => {
                user => [0,0,2,2],
                council => [0,0,2,2],
                totals => [2,2,6,6],
            },
            counts_after => {
                user => [0,0,1,1],
                council => [0,0,1,1],
                totals => [1,1,3,3],
            },
            report_counts => [2,4,0],
            report_counts_after => [1,2,0],
        },
        {
            desc => 'Limit display by ward',
            p1 => {
                    state   => 'confirmed',
                    conf_dt => DateTime->now()->subtract( weeks => 1 ),
                    category => 'Potholes',
                    # in real life it has commas around it and the search
                    # uses them
                    areas => ',20720,',
            },
            p2 => {
                    state   => 'fixed - council',
                    conf_dt => DateTime->now()->subtract( weeks => 1 ),
                    mark_dt => DateTime->now()->subtract( weeks => 1 ),
                    category => 'Litter',
                    areas => ',20720,',
            },
            ward => 20720,
            counts => {
                user => [0,0,2,2],
                council => [0,0,3,3],
                totals => [2,2,8,8],
            },
            counts_after => {
                user => [0,0,0,0],
                council => [0,0,1,1],
                totals => [0,0,2,2],
            },
            report_counts => [2,6,0],
            report_counts_after => [0,2,0],
        },
    ) {
        subtest $test->{desc} => sub {
            make_problem( $test->{p1} ) if $test->{p1};
            make_problem( $test->{p2} ) if $test->{p2};

            $mech->get_ok('/dashboard');

            $res = $categories->scrape( $mech->content );

            foreach my $row ( keys %{ $test->{counts} } ) {
                check_row( $res, $row, $test->{counts}->{$row} );
            }

            check_report_counts( $res, $test->{report_counts} );

            $mech->submit_form_ok( {
                with_fields => {
                    category => $test->{category},
                    ward     => $test->{ward},
                }
            } );

            $res = $categories->scrape( $mech->content );

            foreach my $row ( keys %{ $test->{counts_after} } ) {
                check_row( $res, $row, $test->{counts_after}->{$row} );
            }
            check_report_counts( $res, $test->{report_counts_after} );
        };
    }

    delete_problems();

    for my $test (
        {
            desc => 'Selecting no state does nothing',
            p1 => {
                    state   => 'fixed - user',
                    conf_dt => DateTime->now()->subtract( minutes => 1 ),
                    category => 'Potholes',
            },
            p2 => {
                    state   => 'confirmed',
                    conf_dt => DateTime->now()->subtract( minutes => 1 ),
                    category => 'Litter',
            },
            state => '',
            report_counts => [2,0,0],
            report_counts_after => [2,0,0],
        },
        {
            desc => 'limit by state works',
            state => 'fixed - council',
            report_counts => [2,0,0],
            report_counts_after => [1,0,0],
        },
        {
            desc => 'All fixed states count as fixed',
            p1 => {
                    state   => 'fixed - council',
                    conf_dt => DateTime->now()->subtract( minutes => 1 ),
                    category => 'Potholes',
            },
            p2 => {
                    state   => 'fixed',
                    conf_dt => DateTime->now()->subtract( minutes => 1 ),
                    category => 'Potholes',
            },
            state => 'fixed',
            report_counts => [4,0,0],
            report_counts_after => [3,0,0],
        },
    ) {
        subtest $test->{desc} => sub {
            make_problem( $test->{p1} ) if $test->{p1};
            make_problem( $test->{p2} ) if $test->{p2};

            $mech->get_ok('/dashboard');

            $res = $categories->scrape( $mech->content );

            check_report_counts( $res, $test->{report_counts} );

            $mech->submit_form_ok( {
                with_fields => {
                    state => $test->{state},
                }
            } );

            $res = $categories->scrape( $mech->content );

            check_report_counts( $res, $test->{report_counts_after} );
        };
    }

    subtest 'export as csv' => sub {
        make_problem( {
            detail => "this report\nis split across\nseveral lines",
            state => "confirmed",
            conf_dt => DateTime->now(),
            areas => 62883,
        } );
        $mech->get_ok('/dashboard?export=1');
        open my $data_handle, '<', \$mech->content;
        my $csv = Text::CSV->new( { binary => 1 } );
        my @rows;
        while ( my $row = $csv->getline( $data_handle ) ) {
            push @rows, $row;
        }
        is scalar @rows, 6, '1 (header) + 5 (reports) = 6 lines';

        is scalar @{$rows[0]}, 18, '18 columns present';

        is_deeply $rows[0],
            [
                'Report ID',
                'Title',
                'Detail',
                'User Name',
                'Category',
                'Created',
                'Confirmed',
                'Acknowledged',
                'Fixed',
                'Closed',
                'Status',
                'Latitude',
                'Longitude',
                'Nearest Postcode',
                'Ward',
                'Easting',
                'Northing',
                'Report URL',
            ],
            'Column headers look correct';

        is $rows[5]->[14], 'Bradford-on-Avon', 'Ward column is name not ID';

        is $rows[5]->[15], '610591', 'Correct Easting conversion';
        is $rows[5]->[16], '126573', 'Correct Northing conversion';
    };
};
restore_time;

sub make_problem {
    my $args = shift;

    my $p = FixMyStreet::App->model('DB::Problem')->create( {
        title => 'a problem',
        name => 'a user',
        anonymous => 1,
        detail => $args->{detail} || 'some detail',
        state => $args->{state},
        confirmed => $args->{conf_dt},
        whensent => $args->{conf_dt},
        lastupdate => $args->{mark_dt} || $args->{conf_dt},
        bodies_str => $body->id,
        postcode => 'EH99 1SP',
        latitude => '51',
        longitude => '1',
        areas      => $args->{areas} || $test_ward,
        used_map => 0,
        user_id => $p_user->id,
        category => $args->{category} || 'Other',
    } );

    if ( $args->{state} ne 'confirmed' ) {
        my $c = FixMyStreet::App->model('DB::Comment')->create( {
            problem => $p,
            user_id => $p_user->id,
            state => 'confirmed',
            problem_state => $args->{state} =~ /^fixed - user|fixed$/ ? undef : $args->{state},
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

sub check_report_counts {
    my $res = shift;
    my $counts = shift;

    for my $i ( 0 .. 2 ) {
        if ( $counts->[$i] == 0 ) {
            is_deeply $res->{report_lists}->[$i], {}, "No reports for column $i";
        } else {
            if ( ref( $res->{report_lists}->[$i]->{reports} ) eq 'ARRAY' ) {
                is scalar @{ $res->{report_lists}->[$i]->{reports} }, $counts->[$i], "Correct report count for column $i";
            } else {
                fail "Correct report count for column $i ( no reports )";
            }
        }
    }
}

sub delete_problems {
    FixMyStreet::App->model('DB::Comment')
      ->search( { 'problem.bodies_str' => $body->id }, { join => 'problem' } )
      ->delete;
    FixMyStreet::App->model('DB::Problem')
      ->search( { bodies_str => $body->id } )->delete();
}

done_testing;
