use Test::MockModule;

use FixMyStreet::TestMech;
use Catalyst::Test 'FixMyStreet::App';
use FixMyStreet::Script::Reports;
use Open311::PostServiceRequestUpdates;

use_ok 'FixMyStreet::Cobrand::WestNorthants';
use_ok 'FixMyStreet::Cobrand::NorthNorthants';

my $mech = FixMyStreet::TestMech->new;

use open ':std', ':encoding(UTF-8)';

for my $test ( {
    northants_area_id => 164185,
    opposite => 164186,
    northants_name => 'North Northamptonshire',
    moniker => 'northnorthants',
    areas_to_include => {
        'corby' => '2398',
        'kettering' => '2396',
        'wellingborough' => '2395',
        'north northamptonshire' => '164185',
    },
    cobrand_pkg => 'FixMyStreet::Cobrand::NorthNorthants',
}, {
    northants_area_id => 164186,
    opposite => 164185,
    northants_name => 'West Northamptonshire',
    moniker => 'westnorthants',
    areas_to_include => {
        'south northants' => '2392',
        'daventry' => '2394',
        'northampton' => '2397',
        'west northamptonshire' => '164186',
    },
    cobrand_pkg => 'FixMyStreet::Cobrand::WestNorthants',
} ) {

my $nh = $mech->create_body_ok($test->{northants_area_id}, 'Northamptonshire Highways', { cobrand => 'northamptonshire' });
my $northants = $mech->create_body_ok($test->{northants_area_id}, $test->{northants_name},{
    send_method => 'Open311', api_key => 'key', 'endpoint' => 'e', 'jurisdiction' => 'j', send_comments => 1, can_be_devolved => 1, cobrand => $test->{moniker} });

my $counciluser = $mech->create_user_ok($test->{moniker} . 'counciluser@example.com', name => 'Council User', from_body => $northants);
my $user = $mech->create_user_ok($test->{moniker} . 'user@example.com', name => 'User');

my $northants_contact = $mech->create_contact_ok(
    body_id => $northants->id,
    category => 'Trees',
    email => 'trees@example.com',
);

my $nh_contact = $mech->create_contact_ok(
    body_id => $nh->id,
    category => 'Trees',
    email => 'trees-nh@example.com',
);

$mech->create_contact_ok(
    body_id => $northants->id,
    category => 'Hedges',
    email => 'hedges@example.com',
    send_method => 'Email',
);

my ($report) = $mech->create_problems_for_body(1, $northants->id, 'Defect Problem', {
    whensent => DateTime->now()->subtract( minutes => 5 ),
    cobrand => $test->{moniker},
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

$northants->update( { comment_user_id => $counciluser->id } );

subtest 'Check updates not sent for defects' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS=> $test->{moniker},
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
        ALLOWED_COBRANDS=> $test->{moniker},
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        my $updates = Open311::PostServiceRequestUpdates->new();
        $updates->send;
    };

    $comment->discard_changes;
    is $comment->send_fail_count, 1, "comment sending attempted";
};

my ($res, $c) = ctx_request('/');
my $cobrand = $test->{cobrand_pkg}->new({ c => $c });

subtest 'check updates disallowed correctly' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS=> $test->{moniker},
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => {
            updates_allowed => {
                $test->{moniker} => 'notopen311-open',
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
        ALLOWED_COBRANDS=> $test->{moniker},
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => {
            extra_state_mapping => {
                $test->{moniker} => {
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
        ALLOWED_COBRANDS=> $test->{moniker},
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => {
            extra_state_mapping => {
                $test->{moniker} => {
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
        ALLOWED_COBRANDS=> $test->{moniker},
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => {
            extra_state_mapping => {
                $test->{moniker} => {
                    fixed => {
                        further => 'Under further investigation'
                    }
                },
                fixmystreet => {
                    $test->{northants_name} => {
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
        ALLOWED_COBRANDS=> $test->{moniker},
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
                $test->{moniker} => {
                    investigating => {
                        further => 'Under further investigation'
                    }
                },
                fixmystreet => {
                    $test->{northants_name} => {
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
                $test->{moniker} => {
                    fixed => {
                        further => 'Under further investigation'
                    }
                },
                fixmystreet => {
                    $test->{northants_name} => {
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
        ALLOWED_COBRANDS=> $test->{moniker},
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => {
            extra_state_mapping => {
                $test->{moniker} => {
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
        ALLOWED_COBRANDS => $test->{moniker},
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

my $staffuser = $mech->create_user_ok($test->{moniker} . 'counciluser@example.com', name => 'Council User',
    from_body => $northants, password => 'password');
$mech->log_in_ok( $staffuser->email );

subtest 'Dashboard CSV extra columns' => sub {
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => $test->{moniker},
    }, sub {
        $mech->get_ok('/dashboard?export=1');
    };
    $mech->content_contains('"Site Used","Reported As","External ID"');
    $mech->content_contains($test->{moniker} . ",," . $report->external_id);
};

subtest 'Includes old Northamptonshire reports' => sub {

    subtest 'Includes all Northamptonshire reports before April 2021' => sub {
        my ($old_enough) = $mech->create_problems_for_body(1, $nh->id, 'nh problem', {
            cobrand => 'northamptonshire',
            user => $user,
            areas => "," . $test->{opposite} . ",",
            created => '2021-03-31',
        });
        my ($too_recent) = $mech->create_problems_for_body(1, $nh->id, 'nh problem', {
            cobrand => 'northamptonshire',
            user => $user,
            areas => "," . $test->{opposite} . ",",
            created => '2021-04-01',
        });
        my $rs = $cobrand->problems;
        ok $rs->find($old_enough->id), "includes report out of boundary but before April 2021";
        is $rs->find($too_recent->id), undef, "does not include report out of boundary after April 2021";
    };

    subtest 'Includes reports within boundary after April 2021' => sub {
        my %areas_to_include = %{ $test->{areas_to_include} };
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

    subtest 'Comments left on Northamptonshire reports are visible' => sub {
            FixMyStreet::override_config {
                MAPIT_URL => 'http://mapit.uk/',
                ALLOWED_COBRANDS => $test->{moniker},
            }, sub {

                my ($nhreport) = $mech->create_problems_for_body(1, $nh->id, 'Defect Problem', {
                    created => '2021-03-24',
                    confirmed => '2021-03-24',
                    cobrand => 'northamptonshire',
                    send_method_used => 'Open311',
                    user => $counciluser
                });

                my $nhcomment = FixMyStreet::DB->resultset('Comment')->create( {
                    mark_fixed => 0,
                    user => $user,
                    problem => $nhreport,
                    anonymous => 0,
                    text => 'this is a comment left on a Northamptonshire Highways report',
                    confirmed => DateTime->now,
                    state => 'confirmed',
                    problem_state => 'confirmed',
                    cobrand => 'default',
                } );

                $mech->get_ok('/report/' . $nhreport->id);
                $mech->content_contains('this is a comment left on a Northamptonshire Highways report');
            };
    };
};

subtest 'Staff have perms for northamptonshire highways reports' => sub {
    $staffuser->user_body_permissions->create({ body => $northants, permission_type => 'report_edit' });
    my ($p) = $mech->create_problems_for_body(1, $nh->id, 'Northamptonshire Highways Problem', {
        cobrand => 'northamptonshire',
        user => $user,
        created => '2021-03-31',
    });
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => [$test->{moniker}, 'northamptonshire'],
    }, sub {
        $mech->host($test->{moniker} . ".fixmystreet.com");
        $mech->log_in_ok( $staffuser->email );
        $mech->get_ok('/admin/report_edit/' . $p->id);
    };
};

}

done_testing();
