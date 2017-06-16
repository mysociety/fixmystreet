use FixMyStreet::TestMech;
use mySociety::MaPit;
use FixMyStreet::App;
use DateTime;

ok( my $mech = FixMyStreet::TestMech->new, 'Created mech object' );

$mech->create_body_ok(2514, 'Birmingham City Council');
my $body_edin_id = $mech->create_body_ok(2651, 'City of Edinburgh Council')->id;
my $body_west_id = $mech->create_body_ok(2504, 'Westminster City Council')->id;
my $body_fife_id = $mech->create_body_ok(2649, 'Fife Council')->id;
my $body_slash_id = $mech->create_body_ok(10000, 'Electricity/Gas Council')->id;

my @edinburgh_problems = $mech->create_problems_for_body(3, $body_edin_id, 'All reports');
my @westminster_problems = $mech->create_problems_for_body(5, $body_west_id, 'All reports');
my @fife_problems = $mech->create_problems_for_body(15, $body_fife_id, 'All reports');

is scalar @westminster_problems, 5, 'correct number of westminster problems created';
is scalar @edinburgh_problems, 3, 'correct number of edinburgh problems created';
is scalar @fife_problems, 15, 'correct number of fife problems created';

$edinburgh_problems[1]->update( {
    state => 'in progress',
    confirmed => DateTime->now()->subtract( weeks => 6 ),
    lastupdate => DateTime->now()->subtract( weeks => 5 ),
} );

$fife_problems[1]->update( {
    state => 'fixed - user',
    confirmed => DateTime->now()->subtract( weeks => 6 ),
    lastupdate => DateTime->now()->subtract( weeks => 5 ),
});

$fife_problems[2]->update( {
    state => 'fixed - user',
    confirmed => DateTime->now()->subtract( weeks => 2 ),
    lastupdate => DateTime->now()->subtract( weeks => 1 ),
});

$fife_problems[3]->update( {
    state => 'fixed - user',
    confirmed => DateTime->now()->subtract( weeks => 10 ),
    lastupdate => DateTime->now()->subtract( weeks => 9 ),
});

$fife_problems[4]->update( {
    confirmed => DateTime->now()->subtract( weeks => 10 ),
    lastupdate => DateTime->now()->subtract( weeks => 9 ),
});

$fife_problems[5]->update( {
    confirmed => DateTime->now()->subtract( weeks => 7 ),
    lastupdate => DateTime->now()->subtract( weeks => 5 ),
});

$fife_problems[6]->update( {
    confirmed => DateTime->now()->subtract( weeks => 7 ),
    lastupdate => DateTime->now()->subtract( weeks => 2 ),
});

$fife_problems[7]->update( {
    confirmed => DateTime->now()->subtract( weeks => 10 ),
    lastupdate => DateTime->now()->subtract( weeks => 6 ),
});

$fife_problems[8]->update( {
    confirmed => DateTime->now()->subtract( weeks => 10 ),
    lastupdate => DateTime->now()->subtract( weeks => 2 ),
});

$fife_problems[9]->update( {
    state => 'fixed - user',
    confirmed => DateTime->now()->subtract( weeks => 10 ),
    lastupdate => DateTime->now()->subtract( weeks => 7 ),
});

$fife_problems[10]->update( {
    state => 'hidden',
});

# Run the cron script that makes the data for /reports so we don't get an error.
use FixMyStreet::Script::UpdateAllReports;
FixMyStreet::Script::UpdateAllReports::generate();

# check that we can get the page
$mech->get_ok('/reports');
$mech->title_like(qr{Summary reports});
$mech->content_contains('Birmingham');

my $stats = $mech->extract_report_stats;

is $stats->{'City of Edinburgh Council'}->[1], 2, 'correct number of new reports for Edinburgh';
is $stats->{'City of Edinburgh Council'}->[2], 1, 'correct number of older reports for Edinburgh';

is $stats->{'Westminster City Council'}->[1], 5, 'correct number of reports for Westminster';

is $stats->{'Fife Council'}->[1], 5, 'correct number of new reports for Fife';
is $stats->{'Fife Council'}->[2], 4, 'correct number of old reports for Fife';
is $stats->{'Fife Council'}->[3], 1, 'correct number of unknown reports for Fife';
is $stats->{'Fife Council'}->[4], 3, 'correct number of fixed reports for Fife';
is $stats->{'Fife Council'}->[5], 1, 'correct number of older fixed reports for Fife';

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    $mech->follow_link_ok( { text_regex => qr/Birmingham/ } );
    $mech->get_ok('/reports/Westminster');
};

$mech->title_like(qr/Westminster City Council/);
$mech->content_contains('Westminster City Council');
$mech->content_contains('All reports Test 3 for ' . $body_west_id, 'problem to be marked non public visible');

my $problems = $mech->extract_problem_list;
is scalar @$problems, 5, 'correct number of problems displayed';

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    $mech->get_ok('/reports');
    $mech->follow_link_ok({ url_regex => qr{/reports/Electricity_Gas\+Council} });
    is $mech->uri->path, '/reports/Electricity_Gas+Council', 'Path is correct';

    $mech->get_ok('/reports/City+of+Edinburgh?t=new');
};
$problems = $mech->extract_problem_list;
is scalar @$problems, 2, 'correct number of new problems displayed';

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    $mech->get_ok('/reports/City+of+Edinburgh?t=older');
};
$problems = $mech->extract_problem_list;
is scalar @$problems, 1, 'correct number of older problems displayed';

for my $test (
    {
        desc => 'new fife problems on report page',
        type => 'new',
        expected => 5
    },
    {
        desc => 'older fife problems on report page',
        type => 'older',
        expected => 4
    },
    {
        desc => 'unknown fife problems on report page',
        type => 'unknown',
        expected => 1
    },
    {
        desc => 'fixed fife problems on report page',
        type => 'fixed',
        expected => 3
    },
    {
        desc => 'older_fixed fife problems on report page',
        type => 'older_fixed',
        expected => 1
    },
) {
    subtest $test->{desc} => sub {
        FixMyStreet::override_config {
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $mech->get_ok('/reports/Fife+Council?t=' . $test->{type});
        };

        $problems = $mech->extract_problem_list;
        is scalar @$problems, $test->{expected}, 'correct number of ' . $test->{type} . ' problems displayed';
    };
}

my $private = $westminster_problems[2];
ok $private->update( { non_public => 1 } ), 'problem marked non public';

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    $mech->get_ok('/reports/Westminster');
};
$problems = $mech->extract_problem_list;
is scalar @$problems, 4, 'only public problems are displayed';

$mech->content_lacks('All reports Test 3 for ' . $body_west_id, 'non public problem is not visible');

$mech->get_ok('/reports');
$stats = $mech->extract_report_stats;
is $stats->{'Westminster City Council'}->[1], 5, 'non public reports included in stats';

subtest "test fiksgatami all reports page" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'fiksgatami' ],
    }, sub {
        $mech->create_body_ok(3, 'Oslo');
        ok $mech->host("fiksgatami.no"), 'change host to fiksgatami';
        $mech->get_ok('/reports');
        # There should only be one Oslo
        $mech->content_contains('Oslo');
        $mech->content_unlike(qr{Oslo">Oslo.*Oslo}s);
    }
};

subtest "test greenwich all reports page" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'greenwich' ],
        MAPIT_URL => 'http://mapit.uk/'
    }, sub {
        my $body = $mech->create_body_ok(2493, 'Royal Borough of Greenwich');
        my $deleted_contact = $mech->create_contact_ok(
            body_id => $body->id,
            category => 'Deleted',
            email => 'deleted@example.com',
            deleted => 1
        );
        ok $mech->host("greenwich.fixmystreet.com"), 'change host to greenwich';
        $mech->get_ok('/reports/Royal+Borough+of+Greenwich');
        # There should not be deleted categories in the list
        my $category_select = $mech->forms()->[0]->find_input('filter_category');
        is $category_select, undef, 'deleted categories are not shown';

        # Clean up after the test
        $deleted_contact->delete;
    }
};

subtest "it lists shortlisted reports" => sub {
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/'
    }, sub {
        my $body = FixMyStreet::App->model('DB::Body')->find( $body_edin_id );
        my $user = $mech->log_in_ok( 'test@example.com' );
        $user->update({ from_body => $body });
        $user->user_body_permissions->find_or_create({
            body => $body,
            permission_type => 'planned_reports',
        });

        my ($shortlisted_problem) = $mech->create_problems_for_body(1, $body_edin_id, 'Shortlisted report');
        my ($unshortlisted_problem) = $mech->create_problems_for_body(1, $body_edin_id, 'Unshortlisted report');
        my ($removed_from_shortlist_problem) = $mech->create_problems_for_body(1, $body_edin_id, 'Removed from shortlist report');

        $user->add_to_planned_reports($shortlisted_problem);
        $user->add_to_planned_reports($removed_from_shortlist_problem);
        $user->remove_from_planned_reports($removed_from_shortlist_problem);

        $mech->get_ok('/reports/City+of+Edinburgh+Council');
        $mech->content_contains('<option value="shortlisted">Shortlisted</option>');
        $mech->content_contains('<option value="unshortlisted">Unshortlisted</option>');

        $mech->get_ok('/reports/City+of+Edinburgh+Council?status=shortlisted');

        $mech->content_contains('Shortlisted report');
        $mech->content_lacks('Unshortlisted report');
        $mech->content_lacks('Removed from shortlist report');

        $mech->get_ok('/reports/City+of+Edinburgh+Council?status=shortlisted,open');

        $mech->content_contains('Shortlisted report');
        $mech->content_lacks('Unshortlisted report');
        $mech->content_lacks('Removed from shortlist report');

        $mech->get_ok('/reports/City+of+Edinburgh+Council?status=unshortlisted,open');

        $mech->content_contains('Unshortlisted report');
        $mech->content_contains('Removed from shortlist report');
        $mech->content_lacks('Shortlisted report');

        $user->admin_user_body_permissions->delete;

        $mech->get_ok('/reports/City+of+Edinburgh+Council');
        $mech->content_lacks('<option value="shortlisted">Shortlisted</option>');
        $mech->content_lacks('<option value="unshortlisted">Unshortlisted</option>');
    };
};

done_testing();
