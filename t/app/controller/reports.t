use Test::MockTime qw(:all);
use FixMyStreet::TestMech;
use mySociety::MaPit;
use FixMyStreet::App;
use FixMyStreet::Script::UpdateAllReports;
use DateTime;

set_absolute_time('2017-07-07T16:00:00');
END {
    restore_time;
}

ok( my $mech = FixMyStreet::TestMech->new, 'Created mech object' );

# Run the cron script with empty database
FixMyStreet::Script::UpdateAllReports::generate_dashboard();

$mech->create_body_ok(2514, 'Birmingham City Council');
my $body_edin_id = $mech->create_body_ok(2651, 'City of Edinburgh Council')->id;
my $body_west_id = $mech->create_body_ok(2504, 'Westminster City Council')->id;
my $body_fife_id = $mech->create_body_ok(2649, 'Fife Council')->id;
my $body_slash_id = $mech->create_body_ok(10000, 'Electricity/Gas Council')->id;

my @edinburgh_problems = $mech->create_problems_for_body(3, $body_edin_id, 'All reports', { category => 'Potholes' });
my @westminster_problems = $mech->create_problems_for_body(5, $body_west_id, 'All reports', { category => 'Graffiti' });
my @fife_problems = $mech->create_problems_for_body(15, $body_fife_id, 'All reports', { category => 'Flytipping' });

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
FixMyStreet::Script::UpdateAllReports::generate_dashboard();

# check that we can get the page
$mech->get_ok('/reports');
$mech->title_like(qr{Dashboard});
$mech->content_contains('Birmingham');

$mech->content_contains('&quot;Apr&quot;,&quot;May&quot;,&quot;Jun&quot;,&quot;Jul&quot;');
$mech->content_contains('5,9,10,22');
$mech->content_contains('2,3,4,4');

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    $mech->submit_form_ok( { with_fields => { body => $body_edin_id } }, 'Submitted dropdown okay' );
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
    $mech->submit_form_ok({ with_fields => { body => $body_slash_id } }, 'Submitted dropdown okay');
    is $mech->uri->path, '/reports/Electricity_Gas+Council', 'Path is correct';

    $mech->get_ok('/reports/City+of+Edinburgh?status=open');
};
$problems = $mech->extract_problem_list;
is scalar @$problems, 3, 'correct number of open problems displayed';

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    $mech->get_ok('/reports/City+of+Edinburgh?status=closed');
};
$problems = $mech->extract_problem_list;
is scalar @$problems, 0, 'correct number of closed problems displayed';

for my $test (
    {
        desc => 'open fife problems on report page',
        type => 'open',
        expected => 10
    },
    {
        desc => 'closed fife problems on report page',
        type => 'closed',
        expected => 0
    },
    {
        desc => 'fixed fife problems on report page',
        type => 'fixed',
        expected => 4
    },
) {
    subtest $test->{desc} => sub {
        FixMyStreet::override_config {
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $mech->get_ok('/reports/Fife+Council?status=' . $test->{type});
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

# No change to numbers if report is non-public
$mech->get_ok('/reports');
$mech->content_contains('&quot;Apr&quot;,&quot;May&quot;,&quot;Jun&quot;,&quot;Jul&quot;');
$mech->content_contains('5,9,10,22');

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
            state => 'deleted',
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
