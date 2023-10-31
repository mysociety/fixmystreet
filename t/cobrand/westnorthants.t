use Test::MockModule;

use FixMyStreet::TestMech;
use Catalyst::Test 'FixMyStreet::App';
use FixMyStreet::Script::Reports;
use Open311::PostServiceRequestUpdates;

use_ok 'FixMyStreet::Cobrand::WestNorthants';

my $mech = FixMyStreet::TestMech->new;

use open ':std', ':encoding(UTF-8)';

my $wnc = $mech->create_body_ok(164186, 'West Northamptonshire Council', {
    send_method => 'Open311', api_key => 'key', 'endpoint' => 'e', 'jurisdiction' => 'j', send_comments => 1, can_be_devolved => 1 }, { cobrand => 'westnorthants' });

my $counciluser = $mech->create_user_ok('counciluser@example.com', name => 'Council User', from_body => $wnc);
my $user = $mech->create_user_ok('user@example.com', name => 'User');

my $wnc_contact = $mech->create_contact_ok(
    body_id => $wnc->id,
    category => 'Trees',
    email => 'trees-wnc@example.com',
);

$mech->create_contact_ok(
    body_id => $wnc->id,
    category => 'Hedges',
    email => 'hedges-wnc@example.com',
    send_method => 'Email',
);

my ($report) = $mech->create_problems_for_body(1, $wnc->id, 'Defect Problem', {
    whensent => DateTime->now()->subtract( minutes => 5 ),
    cobrand => 'westnorthants',
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

$wnc->update( { comment_user_id => $counciluser->id } );

subtest 'Check updates not sent for defects' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS=> 'westnorthants',
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
        ALLOWED_COBRANDS=> 'westnorthants',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        my $updates = Open311::PostServiceRequestUpdates->new();
        $updates->send;
    };

    $comment->discard_changes;
    is $comment->send_fail_count, 1, "comment sending attempted";
};

my ($res, $c) = ctx_request('/');
my $cobrand = FixMyStreet::Cobrand::WestNorthants->new({ c => $c });

subtest 'check updates disallowed correctly' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS=> 'westnorthants',
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => {
            updates_allowed => {
                westnorthants => 'notopen311-open',
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
        ALLOWED_COBRANDS=> 'westnorthants',
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => {
            extra_state_mapping => {
                westnorthants => {
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
        ALLOWED_COBRANDS=> 'westnorthants',
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => {
            extra_state_mapping => {
                westnorthants => {
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
        ALLOWED_COBRANDS=> 'westnorthants',
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => {
            extra_state_mapping => {
                westnorthants => {
                    fixed => {
                        further => 'Under further investigation'
                    }
                },
                fixmystreet => {
                    'West Northamptonshire Council' => {
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
        ALLOWED_COBRANDS=> 'westnorthants',
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
                westnorthants => {
                    investigating => {
                        further => 'Under further investigation'
                    }
                },
                fixmystreet => {
                    'West Northamptonshire Council' => {
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
                westnorthants => {
                    fixed => {
                        further => 'Under further investigation'
                    }
                },
                fixmystreet => {
                    'West Northamptonshire Council' => {
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
        ALLOWED_COBRANDS=> 'westnorthants',
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => {
            extra_state_mapping => {
                westnorthants => {
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
        ALLOWED_COBRANDS => 'westnorthants',
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

subtest 'Dashboard CSV extra columns' => sub {
    my $staffuser = $mech->create_user_ok('counciluser@example.com', name => 'Council User',
        from_body => $wnc, password => 'password');
    $mech->log_in_ok( $staffuser->email );
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'westnorthants',
    }, sub {
        $mech->get_ok('/dashboard?export=1');
    };
    $mech->content_contains('"Site Used","Reported As","External ID"');
    $mech->content_contains('westnorthants,,' . $report->external_id);
};

done_testing();
