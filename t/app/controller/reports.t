use Test::MockTime qw(:all);
use FixMyStreet::TestMech;
use mySociety::MaPit;
use FixMyStreet::DB;
use FixMyStreet::Script::UpdateAllReports;
use DateTime;

set_absolute_time('2017-07-07T16:00:00');
END {
    restore_time;
}

ok( my $mech = FixMyStreet::TestMech->new, 'Created mech object' );

$mech->create_body_ok(2514, 'Birmingham City Council');
my $body_edin_id = $mech->create_body_ok(2651, 'City of Edinburgh Council')->id;
my $body_west_id = $mech->create_body_ok(2504, 'Westminster City Council')->id;
my $body_fife_id = $mech->create_body_ok(2649, 'Fife Council')->id;
my $body_slash_id = $mech->create_body_ok(10000, 'Electricity/Gas Council')->id;

$mech->create_contact_ok(body_id => $body_edin_id, category => 'Potholes', email => 'potholes@example.org');
$mech->create_contact_ok(body_id => $body_west_id, category => 'Graffiti', email => 'graffiti@example.org');
$mech->create_contact_ok(body_id => $body_fife_id, category => 'Flytipping', email => 'flytipping@example.org');
my @edinburgh_problems = $mech->create_problems_for_body(3, $body_edin_id, 'All reports', { category => 'Potholes' });
my @westminster_problems = $mech->create_problems_for_body(5, $body_west_id, 'All reports', { category => 'Graffiti' });
my @fife_problems = $mech->create_problems_for_body(15, $body_fife_id, 'All reports', { category => 'Flytipping' });

my $west_trans = FixMyStreet::DB->resultset('Translation')->find_or_create({
    tbl => 'body',
    object_id => $body_west_id,
    col => 'name',
    lang => 'de',
    msgstr => 'De Westminster'
});

ok $west_trans, 'created westminster translation';

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

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'fixmystreet',
}, sub {
    subtest 'Test the cron script old-data (for the table no longer used by default)' => sub {
        FixMyStreet::Script::UpdateAllReports::generate(1);

        # Old style page no longer exists in core, but let's just check the code works okay
        my $cobrand = FixMyStreet::Cobrand->get_class_for_moniker('fixmystreet')->new();
        FixMyStreet::DB->schema->cobrand($cobrand);
        my @bodies = FixMyStreet::DB->resultset('Body')->active->translated->all_sorted;
        is $bodies[0]->{url}->(), '/reports/Birmingham';
    };
};

# Run the cron script that makes the data for /reports so we don't get an error.
my $data = FixMyStreet::Script::UpdateAllReports::generate_dashboard();

# check that we can get the page
FixMyStreet::override_config {
    TEST_DASHBOARD_DATA => $data,
}, sub {
    $mech->get_ok('/reports');
};
$mech->title_like(qr{Dashboard});
$mech->content_contains('Birmingham');

$mech->content_contains('&quot;Apr&quot;,&quot;May&quot;,&quot;Jun&quot;,&quot;Jul&quot;');
$mech->content_contains('5,9,10,22');
$mech->content_contains('2,3,4,4');

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'fixmystreet',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => { category_groups => { fixmystreet => 1 } },
}, sub {
    $mech->submit_form_ok( { with_fields => { body => $body_edin_id } }, 'Submitted dropdown okay' );
    is $mech->uri->path, '/reports/City+of+Edinburgh';
    $mech->content_contains('<optgroup label="">');

    subtest "test ward pages" => sub {
        $mech->get_ok('/reports/Birmingham/Bad-Ward');
        is $mech->uri->path, '/reports/Birmingham';
        $mech->get_ok('/reports/Birmingham/Bordesley+and+Highgate');
        is $mech->uri->path, '/reports/Birmingham/Bordesley+and+Highgate';
        $mech->get_ok('/reports/Birmingham/Bordesley+and+Highgate|Birchfield');
        is $mech->uri->path, '/reports/Birmingham/Bordesley+and+Highgate%7CBirchfield';
        $mech->content_contains('Birchfield, Bordesley &amp; Highgate');
    };

    $mech->get_ok('/reports/Westminster');
};

$mech->title_like(qr/Westminster City Council/);
$mech->content_contains('Westminster City Council');
$mech->content_contains('All reports Test 3 for ' . $body_west_id, 'problem to be marked non public visible');

my $problems = $mech->extract_problem_list;
is scalar @$problems, 5, 'correct number of problems displayed';

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    TEST_DASHBOARD_DATA => $data,
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

for my $permission( qw/ report_inspect report_mark_private / ) {
    subtest "user with $permission permission can see non public reports" => sub {
        my $body = FixMyStreet::DB->resultset('Body')->find( $body_west_id );
        my $body2 = FixMyStreet::DB->resultset('Body')->find( $body_edin_id );
        my $user = $mech->log_in_ok( 'test@example.com' );

        # from body, no permission
        $user->user_body_permissions->delete();
        $user->update({ from_body => $body });

        FixMyStreet::override_config {
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $mech->get_ok('/reports/Westminster');
        };
        $problems = $mech->extract_problem_list;
        is scalar @$problems, 4, 'only public problems are displayed if no permission';
        $mech->content_lacks('All reports Test 3 for ' . $body_west_id, 'non public problem is not visible if no permission');
        $mech->content_lacks('<option value="non_public">Private only</option>');

        # from body, no permission, limited to private in url
        FixMyStreet::override_config {
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $mech->get_ok('/reports/Westminster?status=non_public');
        };
        $problems = $mech->extract_problem_list;
        is scalar @$problems, 4, 'only public problems are displayed if no permission, despite override';
        $mech->content_lacks('All reports Test 3 for ' . $body_west_id, 'non public problem is not visible despite override');

        # from body, has permission
        $user->user_body_permissions->find_or_create({
            body => $body,
            permission_type => $permission,
        });

        FixMyStreet::override_config {
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $mech->get_ok('/reports/Westminster');
        };
        $problems = $mech->extract_problem_list;
        is scalar @$problems, 5, 'public and non-public problems are displayed if permission';
        $mech->content_contains('All reports Test 3 for ' . $body_west_id, 'non public problem is visible if permission');
        $mech->content_contains('<option value="non_public">Private only</option>');

        # From body, limited to private only
        FixMyStreet::override_config {
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $mech->get_ok('/reports/Westminster?status=non_public');
        };
        $problems = $mech->extract_problem_list;
        is scalar @$problems, 1, 'only non-public problems are displayed with non_public filter';
        $mech->content_contains('All reports Test 3 for ' . $body_west_id, 'non public problem is visible with non_public filter');
        $mech->content_lacks('All reports Test 4 for ' . $body_west_id, 'public problem is not visible with non_public filter');

        # from other body, has permission
        $user->user_body_permissions->delete();
        $user->update({ from_body => $body2 });
        $user->user_body_permissions->find_or_create({
            body => $body2,
            permission_type => $permission,
        });

        FixMyStreet::override_config {
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $mech->get_ok('/reports/Westminster');
        };
        $problems = $mech->extract_problem_list;
        is scalar @$problems, 4, 'only public problems are displayed for other body user';
        $mech->content_contains('<option value="non_public">Private only</option>');
        $mech->content_lacks('All reports Test 3 for ' . $body_west_id, 'non public problem is not visible for other body user');

        # From other body, limited to private only
        FixMyStreet::override_config {
            MAPIT_URL => 'http://mapit.uk/',
        }, sub {
            $mech->get_ok('/reports/Westminster?status=non_public');
        };
        $problems = $mech->extract_problem_list;
        is scalar @$problems, 4, 'non-public problems are not displayed for other body with override';
        $mech->content_lacks('All reports Test 3 for ' . $body_west_id, 'non public problem is not visible for other body with override');
    };
}

# No change to numbers if report is non-public
FixMyStreet::override_config {
    TEST_DASHBOARD_DATA => $data,
}, sub {
    $mech->get_ok('/reports');
};
$mech->content_contains('&quot;Apr&quot;,&quot;May&quot;,&quot;Jun&quot;,&quot;Jul&quot;');
$mech->content_contains('5,9,10,22');

subtest "test fiksgatami all reports page" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'fiksgatami' ],
        TEST_DASHBOARD_DATA => $data, # Not relevant to what we're testing, just so page loads
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
        my $body = FixMyStreet::DB->resultset('Body')->find( $body_edin_id );
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

subtest "it allows body users to filter by subtypes" => sub {
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/'
    }, sub {
        my $body = FixMyStreet::DB->resultset('Body')->find( $body_edin_id );
        my $user = $mech->log_in_ok( 'test@example.com' );
        $user->update({ from_body => $body });

        my ($investigating_problem) = $mech->create_problems_for_body(1, $body_edin_id, 'Investigating report');
        my ($scheduled_problem) = $mech->create_problems_for_body(1, $body_edin_id, 'A Scheduled report');
        my ($in_progress_problem) = $mech->create_problems_for_body(1, $body_edin_id, 'In progress report');

        $investigating_problem->update({ state => 'investigating' });
        $scheduled_problem->update({ state => 'action scheduled' });
        $in_progress_problem->update({ state => 'in progress' });

        $mech->get_ok('/reports/City+of+Edinburgh+Council');
        $mech->content_contains('<option value="investigating">Investigating</option>');
        $mech->content_contains('<option value="in progress">In progress</option>');
        $mech->content_contains('<option value="action scheduled">Action scheduled</option>');
        $mech->content_contains('<option value="unable to fix">No further action</option>');
        $mech->content_contains('<option value="not responsible">Not responsible</option>');
        $mech->content_contains('<option value="internal referral">Internal referral</option>');
        $mech->content_contains('<option value="duplicate">Duplicate</option>');

        $mech->get_ok('/reports/City+of+Edinburgh+Council?status=investigating');

        $in_progress_problem->discard_changes();

        $mech->content_contains('Investigating report');
        $mech->content_lacks('In progress report');
        $mech->content_lacks('A Scheduled report');

        $mech->get_ok('/reports/City+of+Edinburgh+Council?status=in progress');

        $mech->content_lacks('Investigating report');
        $mech->content_contains('In progress report');
        $mech->content_lacks('A Scheduled report');
    };
};

subtest "it does not allow non body users to filter by subtypes" => sub {
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/'
    }, sub {
        my $user = $mech->log_in_ok( 'test@example.com' );
        $user->update({ from_body => undef });

        $mech->get_ok('/reports/City+of+Edinburgh+Council');
        $mech->content_lacks('<option value="investigating">Investigating</option>');
        $mech->content_lacks('<option value="in progress">In progress</option>');
        $mech->content_lacks('<option value="action scheduled">Action scheduled</option>');
        $mech->content_lacks('<option value="unable to fix">No further action</option>');
        $mech->content_lacks('<option value="not responsible">Not responsible</option>');
        $mech->content_lacks('<option value="internal referral">Internal referral</option>');
        $mech->content_lacks('<option value="duplicate">Duplicate</option>');
    };
};

subtest "it does not allow body users to filter subcategories for other bodies" => sub {
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/'
    }, sub {
        my $body = FixMyStreet::DB->resultset('Body')->find( $body_west_id );
        my $user = $mech->log_in_ok( 'test@example.com' );
        $user->update({ from_body => $body });

        $mech->get_ok('/reports/City+of+Edinburgh+Council');

        $mech->content_lacks('<option value="investigating">Investigating</option>');
        $mech->content_lacks('<option value="in progress">In progress</option>');
        $mech->content_lacks('<option value="action scheduled">Action scheduled</option>');
        $mech->content_lacks('<option value="unable to fix">No further action</option>');
        $mech->content_lacks('<option value="not responsible">Not responsible</option>');
        $mech->content_lacks('<option value="internal referral">Internal referral</option>');
        $mech->content_lacks('<option value="duplicate">Duplicate</option>');
    };
};

subtest "can use translated body name" => sub {
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->get_ok('/reports/De Westminster');
        $mech->title_like(qr/Westminster City Council/);
    };
};

done_testing();
