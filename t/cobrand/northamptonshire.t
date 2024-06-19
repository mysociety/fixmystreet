use Test::MockModule;
use File::Temp 'tempdir';
use FixMyStreet::TestMech;
use Catalyst::Test 'FixMyStreet::App';
use FixMyStreet::Script::Reports;
use Open311::PostServiceRequestUpdates;

use_ok 'FixMyStreet::Cobrand::Northamptonshire';

my $mech = FixMyStreet::TestMech->new;

use open ':std', ':encoding(UTF-8)';

my $nh = $mech->create_body_ok(164186, 'Northamptonshire Highways', {
    send_method => 'Open311', api_key => 'key', 'endpoint' => 'e', 'jurisdiction' => 'j', send_comments => 1, can_be_devolved => 1 }, { cobrand => 'northamptonshire' });
# Associate body with North Northamptonshire area
FixMyStreet::DB->resultset('BodyArea')->find_or_create({
    area_id => 164185,
    body_id => $nh->id,
});

my $wnc = $mech->create_body_ok(164186, 'West Northamptonshire Council');
my $po = $mech->create_body_ok(164186, 'Northamptonshire Police');

my $counciluser = $mech->create_user_ok('counciluser@example.com', name => 'Council User', from_body => $nh);
my $user = $mech->create_user_ok('user@example.com', name => 'User');

my $nh_contact = $mech->create_contact_ok(
    body_id => $nh->id,
    category => 'Trees',
    email => 'trees-nh@example.com',
);

$mech->create_contact_ok(
    body_id => $nh->id,
    category => 'Hedges',
    email => 'hedges-nh@example.com',
    send_method => 'Email',
);

my $wnc_contact = $mech->create_contact_ok(
    body_id => $wnc->id,
    category => 'Flytipping',
    email => 'flytipping-west-northants@example.com',
);

my $po_contact = $mech->create_contact_ok(
    body_id => $po->id,
    category => 'Abandoned vehicles',
    email => 'vehicles-northants-police@example.com',
);

my ($report) = $mech->create_problems_for_body(1, $nh->id, 'Defect Problem', {
    whensent => DateTime->now()->subtract( minutes => 5 ),
    cobrand => 'northamptonshire',
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

$nh->update( { comment_user_id => $counciluser->id } );


subtest 'Check district categories hidden on cobrand' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS=> 'northamptonshire',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->get_ok( '/around' );
        $mech->submit_form_ok( { with_fields => { pc => 'NN1 1NS' } },
            "submit location" );
        is_deeply $mech->page_errors, [], "no errors for pc";

        $mech->follow_link_ok( { text_regex => qr/skip this step/i, },
            "follow 'skip this step' link" );

        $mech->content_contains('Trees');
        $mech->content_lacks('Flytipping');
    };
};

subtest 'Check updates not sent for defects' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS=> 'northamptonshire',
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
        ALLOWED_COBRANDS=> 'northamptonshire',
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        my $updates = Open311::PostServiceRequestUpdates->new();
        $updates->send;
    };

    $comment->discard_changes;
    is $comment->send_fail_count, 1, "comment sending attempted";
};

my ($res, $c) = ctx_request('/');
my $cobrand = FixMyStreet::Cobrand::Northamptonshire->new({ c => $c });

subtest 'check updates disallowed correctly' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS=> 'northamptonshire',
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => {
            updates_allowed => {
                northamptonshire => 'notopen311-open',
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
        ALLOWED_COBRANDS=> 'northamptonshire',
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => {
            extra_state_mapping => {
                northamptonshire => {
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
        ALLOWED_COBRANDS=> 'northamptonshire',
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => {
            extra_state_mapping => {
                northamptonshire => {
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
        ALLOWED_COBRANDS=> 'northamptonshire',
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => {
            extra_state_mapping => {
                northamptonshire => {
                    fixed => {
                        further => 'Under further investigation'
                    }
                },
                fixmystreet => {
                    'Northamptonshire Highways' => {
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
        ALLOWED_COBRANDS=> 'northamptonshire',
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
                northamptonshire => {
                    investigating => {
                        further => 'Under further investigation'
                    }
                },
                fixmystreet => {
                    'Northamptonshire Highways' => {
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
                northamptonshire => {
                    fixed => {
                        further => 'Under further investigation'
                    }
                },
                fixmystreet => {
                    'Northamptonshire Highways' => {
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
        ALLOWED_COBRANDS=> 'northamptonshire',
        MAPIT_URL => 'http://mapit.uk/',
        COBRAND_FEATURES => {
            extra_state_mapping => {
                northamptonshire => {
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
        ALLOWED_COBRANDS => 'northamptonshire',
        #MAPIT_URL => 'http://mapit.uk/',
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

FixMyStreet::override_config {
    ALLOWED_COBRANDS=> [ 'northamptonshire', 'fixmystreet' ],
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    subtest 'Check report emails to county use correct branding' => sub {
        my ($wnc_report) = $mech->create_problems_for_body(1, $wnc->id, 'West Northants Problem', {
            cobrand => 'fixmystreet',
            category => 'Flytipping',
        });

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        my $email = $mech->get_email;
        my $body = $mech->get_text_body_from_email($email);
        like $body, qr/Dear West Northamptonshire Council,/;
        like $body, qr/http:\/\/www\.example\.org/, 'correct link';
        like $body, qr/FixMyStreet is an independent service/, 'Has FMS promo text';
    };

    subtest 'Check report emails to police use correct branding' => sub {
        my ($po_report) = $mech->create_problems_for_body(1, $po->id, 'Northants Police Problem', {
            cobrand => 'fixmystreet',
            category => 'Abandoned vehicles',
        });

        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        my $email = $mech->get_email;
        my $body = $mech->get_text_body_from_email($email);
        like $body, qr/Dear Northamptonshire Police,/;
        like $body, qr/http:\/\/www\.example\.org/, 'correct link';
        like $body, qr/FixMyStreet is an independent service/, 'Has FMS promo text';
    };

    subtest 'Check report emails to highways use correct branding' => sub {
        my ($nh_report) = $mech->create_problems_for_body(1, $nh->id, 'Northants Highways Problem', {
            cobrand => 'fixmystreet',
            category => 'Hedges',
        });
        $mech->clear_emails_ok;
        FixMyStreet::Script::Reports::send();
        my @emails = $mech->get_email;
        my $body = $mech->get_text_body_from_email($emails[0]);
        like $body, qr/Dear Northamptonshire Highways,/;
        like $body, qr/http:\/\/northamptonshire\.example\.org/, 'correct link';
        unlike $body, qr/Never retype another FixMyStreet report/, 'Doesn\'t have FMS promo text';

        $body = $mech->get_text_body_from_email($emails[1]);
        like $body, qr/Your report to Northamptonshire Highways has been logged on FixMyStreet\./;
    };
};

subtest 'Dashboard CSV extra columns' => sub {
    my $UPLOAD_DIR = tempdir( CLEANUP => 1 );
    my $staffuser = $mech->create_user_ok('counciluser@example.com', name => 'Council User',
        from_body => $nh, password => 'password');
    $mech->log_in_ok( $staffuser->email );
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'northamptonshire',
        PHOTO_STORAGE_OPTIONS => { UPLOAD_DIR => $UPLOAD_DIR },
    }, sub {
        $mech->get_ok('/dashboard?export=1');
    };
    $mech->content_contains('"Site Used","Reported As","External ID"');
    $mech->content_contains('northamptonshire,,' . $report->external_id);
};

subtest 'Old report cutoff' => sub {
    my ($report1) = $mech->create_problems_for_body(1, $nh->id, 'West Northants Problem 1', { whensent => '2022-09-11 10:00' });
    my ($report2) = $mech->create_problems_for_body(1, $nh->id, 'West Northants Problem 2', { whensent => '2022-09-12 10:00' });
    my $update1 = $mech->create_comment_for_problem($report1, $user, 'Anonymous User', 'Update text', 't', 'confirmed', undef);
    my $update2 = $mech->create_comment_for_problem($report2, $user, 'Anonymous User', 'Update text', 't', 'confirmed', undef);
    my $cobrand = FixMyStreet::Cobrand::Northamptonshire->new;
    is $cobrand->should_skip_sending_update($update1), 1;
    is $cobrand->should_skip_sending_update($update2), 0;
};

subtest 'Dashboard wards contains North and West wards' => sub {
    my $staffuser = $mech->create_user_ok('counciluser@example.com', name => 'Council User',
        from_body => $nh, password => 'password');
    $mech->log_in_ok( $staffuser->email );
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'northamptonshire',
    }, sub {
        $mech->get_ok('/dashboard');
    };
    $mech->content_contains('Weston By Welland');
    $mech->content_contains('Sulgrave');
};

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    ALLOWED_COBRANDS => 'fixmystreet',
}, sub {
    subtest 'All reports page working' => sub {
        $mech->get_ok("/reports/Northamptonshire+Highways");
        $mech->content_contains('Sulgrave');
        $mech->content_contains('Weston');
        $mech->get_ok("/reports/Northamptonshire+Highways/Weston+By+Welland");
        $mech->content_lacks('Sulgrave');
        $mech->content_contains('Weston');
        $mech->get_ok("/reports/Northamptonshire+Highways/Sulgrave");
        $mech->content_contains('Sulgrave');
        $mech->content_lacks('Weston');
    };
};

done_testing();
