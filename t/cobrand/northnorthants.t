use Test::MockModule;

use FixMyStreet::TestMech;
use Catalyst::Test 'FixMyStreet::App';
use FixMyStreet::Script::Reports;
use Open311::PostServiceRequestUpdates;

use_ok 'FixMyStreet::Cobrand::NorthNorthants';

my $mech = FixMyStreet::TestMech->new;

use open ':std', ':encoding(UTF-8)';

my $nh = $mech->create_body_ok(164185, 'Northamptonshire Highways', {}, { cobrand => 'northamptonshire' });
my $nnc = $mech->create_body_ok(164185, 'North Northamptonshire Council', {
    send_method => 'Open311', api_key => 'key', 'endpoint' => 'e', 'jurisdiction' => 'j', send_comments => 1, can_be_devolved => 1 }, { cobrand => 'northnorthants' });

my $counciluser = $mech->create_user_ok('counciluser@example.com', name => 'Council User', from_body => $nnc);
my $user = $mech->create_user_ok('user@example.com', name => 'User');

my $nnc_contact = $mech->create_contact_ok(
    body_id => $nnc->id,
    category => 'Trees',
    email => 'trees-nnc@example.com',
);

my $nh_contact = $mech->create_contact_ok(
    body_id => $nh->id,
    category => 'Trees',
    email => 'trees-nh@example.com',
);

$mech->create_contact_ok(
    body_id => $nnc->id,
    category => 'Hedges',
    email => 'hedges-nnc@example.com',
    send_method => 'Email',
);

my ($report) = $mech->create_problems_for_body(1, $nnc->id, 'Defect Problem', {
    whensent => DateTime->now()->subtract( minutes => 5 ),
    cobrand => 'northnorthants',
    external_id => 'CRM123',
    send_method_used => 'Open311',
    user => $counciluser
});

my $comment = FixMyStreet::DB->resultset('Comment')->create( {
    mark_fixed => 0,
    user => $user,
    problem => $report,
    anonymous => 0,
    text => 'this is a comment',
    confirmed => DateTime->now,
    state => 'confirmed',
    problem_state => 'confirmed',
    cobrand => 'default',
} );

$nnc->update( { comment_user_id => $counciluser->id } );

subtest 'Check updates not sent for defects' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS=> 'northnorthants',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        my $updates = Open311::PostServiceRequestUpdates->new();
        $updates->send;
    };

    $comment->discard_changes;
    is $comment->send_fail_count, 0, "comment sending not attempted";
    is $comment->send_state, 'skipped', "skipped sending comment";
};

$report->update({ user => $user });
$comment->update({ send_state => 'unprocessed' });
subtest 'check updates sent for non defects' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS=> 'northnorthants',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        my $updates = Open311::PostServiceRequestUpdates->new();
        $updates->send;
    };

    $comment->discard_changes;
    is $comment->send_fail_count, 1, "comment sending attempted";
};

my ($res, $c) = ctx_request('/');
my $cobrand = FixMyStreet::Cobrand::NorthNorthants->new({ c => $c });

subtest 'check updates disallowed correctly' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS=> 'northnorthants',
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => {
            updates_allowed => {
                northnorthants => 'notopen311-open',
            }
        }
    }, sub {
        is $cobrand->updates_disallowed($report), '';
        $report->update({ state => 'closed' });
        is $cobrand->updates_disallowed($report), 'notopen311-open';
        $report->update({ state => 'confirmed', user => $counciluser });
        is $cobrand->updates_disallowed($report), 'notopen311-open';
    };
};

subtest 'check further investigation state' => sub {
    $comment->problem_state('investigating');
    $comment->update();

    FixMyStreet::override_config {
        ALLOWED_COBRANDS=> 'northnorthants',
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => {
            extra_state_mapping => {
                northnorthants => {
                    investigating => {
                        further => 'Under further investigation'
                    }
                }
            }
        }
    }, sub {
        $mech->get_ok('/report/' . $comment->problem_id);
    };

    $mech->content_lacks('Under further investigation');

    $comment->set_extra_metadata('external_status_code' => 'further');
    $comment->update;

    FixMyStreet::override_config {
        ALLOWED_COBRANDS=> 'northnorthants',
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => {
            extra_state_mapping => {
                northnorthants => {
                    investigating => {
                        further => 'Under further investigation'
                    }
                }
            }
        }
    }, sub {
        $mech->get_ok('/report/' . $comment->problem_id);
    };

    $mech->content_contains('Under further investigation');

    FixMyStreet::override_config {
        ALLOWED_COBRANDS=> 'northnorthants',
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => {
            extra_state_mapping => {
                northnorthants => {
                    fixed => {
                        further => 'Under further investigation'
                    }
                },
                fixmystreet => {
                    'North Northamptonshire Council' => {
                        fixed => {
                            further => 'Under further investigation'
                        }
                    }
                }
            }
        }
    }, sub {
        $mech->get_ok('/report/' . $comment->problem_id);
    };

    $mech->content_contains('Investigating');
    $mech->content_lacks('Under further investigation');

    FixMyStreet::override_config {
        ALLOWED_COBRANDS=> 'northnorthants',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->get_ok('/report/' . $comment->problem_id);
    };

    $mech->content_contains('Investigating');
    $mech->content_lacks('Under further investigation');

    FixMyStreet::override_config {
        ALLOWED_COBRANDS=> 'fixmystreet',
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => {
            extra_state_mapping => {
                northnorthants => {
                    investigating => {
                        further => 'Under further investigation'
                    }
                },
                fixmystreet => {
                    'North Northamptonshire Council' => {
                        investigating => {
                            further => 'Under further investigation'
                        }
                    }
                }
            }
        }
    }, sub {
        $mech->get_ok('/report/' . $comment->problem_id);
    };

    $mech->content_contains('Under further investigation');

    FixMyStreet::override_config {
        ALLOWED_COBRANDS=> 'fixmystreet',
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => {
            extra_state_mapping => {
                northnorthants => {
                    fixed => {
                        further => 'Under further investigation'
                    }
                },
                fixmystreet => {
                    'North Northamptonshire Council' => {
                        fixed => {
                            further => 'Under further investigation'
                        }
                    }
                }
            }
        }
    }, sub {
        $mech->get_ok('/report/' . $comment->problem_id);
    };

    $mech->content_contains('Investigating');
    $mech->content_lacks('Under further investigation');

    FixMyStreet::override_config {
        ALLOWED_COBRANDS=> 'fixmystreet',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->get_ok('/report/' . $comment->problem_id);
    };

    $mech->content_contains('Investigating');
    $mech->content_lacks('Under further investigation');

    $comment->set_extra_metadata('external_status_code' => '');
    $comment->update;
    my $comment2 = FixMyStreet::DB->resultset('Comment')->create( {
        mark_fixed => 0,
        user => $user,
        problem => $report,
        anonymous => 0,
        text => 'this is a comment',
        confirmed => DateTime->now,
        state => 'confirmed',
        problem_state => 'investigating',
        cobrand => 'default',
    } );
    $comment2->set_extra_metadata('external_status_code' => 'further');
    $comment2->update;

    FixMyStreet::override_config {
        ALLOWED_COBRANDS=> 'northnorthants',
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => {
            extra_state_mapping => {
                northnorthants => {
                    investigating => {
                        further => 'Under further investigation'
                    }
                }
            }
        }
    }, sub {
        $mech->get_ok('/report/' . $comment->problem_id);
    };

    $mech->content_contains('Investigating');
    $mech->content_contains('Under further investigation');
};

subtest 'check pin colour / reference shown' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'northnorthants',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        is $cobrand->pin_colour($report, 'around'), 'blue';
        $mech->get_ok('/report/' . $report->id);
        $mech->content_lacks('ref:&nbsp;' . $report->id);
        $report->update({ user => $user });
        is $cobrand->pin_colour($report, 'around'), 'yellow';
        is $cobrand->pin_colour($report, 'my'), 'red';
        $mech->get_ok('/report/' . $report->id);
        $mech->content_contains('ref:&nbsp;' . $report->id);
    };
};

my $staffuser = $mech->create_user_ok('counciluser@example.com', name => 'Council User',
    from_body => $nnc, password => 'password');
$mech->log_in_ok( $staffuser->email );

subtest 'Dashboard CSV extra columns' => sub {
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'northnorthants',
    }, sub {
        $mech->get_ok('/dashboard?export=1');
    };
    $mech->content_contains('"Site Used","Reported As","External ID"');
    $mech->content_contains('northnorthants,,' . $report->external_id);
};

subtest 'Includes old Northamptonshire reports' => sub {

    subtest 'Includes all Northamptonshire reports before April 2021' => sub {
        my ($old_enough) = $mech->create_problems_for_body(1, $nh->id, 'nh problem', {
            cobrand => 'northamptonshire',
            user => $user,
            areas => ',164186,', # In North Northamptonshire.
            created => '2021-03-31',
        });
        my ($too_recent) = $mech->create_problems_for_body(1, $nh->id, 'nh problem', {
            cobrand => 'northamptonshire',
            user => $user,
            areas => ',164186,', # In North Northamptonshire.
            created => '2021-04-01',
        });
        my $rs = $cobrand->problems;
        ok $rs->find($old_enough->id), "includes report out of boundary but before April 2021";
        is $rs->find($too_recent->id), undef, "does not include report out of boundary after April 2021";
    };

    subtest 'Includes reports within boundary after April 2021' => sub {
        my %areas_to_include = (
            'corby' => '2398',
            'kettering' => '2396',
            'wellingborough' => '2395',
            'north northamptonshire' => '164185',
        );
        while (my ($area_name, $area_id) = each %areas_to_include) {
            my ($r) = $mech->create_problems_for_body(1, $nh->id, 'nh problem', {
                cobrand => 'northamptonshire',
                user => $user,
                areas => ",$area_id,",
                created => '2021-04-01',
            });
            ok $cobrand->problems->find($r->id), "includes $area_name report after April 2021";
        }
    };
};

subtest 'Staff have perms for northamptonshire highways reports' => sub {
    $staffuser->user_body_permissions->create({ body => $nnc, permission_type => 'report_edit' });
    my ($p) = $mech->create_problems_for_body(1, $nh->id, 'Northamptonshire Highways Problem', {
        cobrand => 'northamptonshire',
        user => $user,
        created => '2021-03-31',
    });
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => ['northnorthants', 'northamptonshire'],
    }, sub {
        $mech->host('northnorthants.fixmystreet.com');
        $mech->log_in_ok( $staffuser->email );
        $mech->get_ok('/admin/report_edit/' . $p->id);
    };
};

done_testing();
