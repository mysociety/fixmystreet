package FixMyStreet::Cobrand::DummyUK;
use parent 'FixMyStreet::Cobrand::UK';

package main;

use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2505, 'Camden Borough Council', {}, { cobrand => 'dummyuk' });

my $user = $mech->create_user_ok('user@example.com');

my ($report) = $mech->create_problems_for_body(1, $body->id, 'Testing', { state => 'fixed', user => $user });

subtest 'reopening by original reporter is permitted by default' => sub {
    $mech->log_out_ok();
    $mech->log_in_ok($user->email);

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'dummyuk' ],
    }, sub {
        $mech->get_ok('/report/' . $report->id);
        $mech->content_contains('This problem has not been fixed');
    };

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'fixmystreet' ],
    }, sub {
        $mech->get_ok('/report/' . $report->id);
        $mech->content_contains('This problem has not been fixed');
    };
};

subtest 'reopening is not permitted when reopening_disallowed is set' => sub {
    $mech->log_out_ok();
    $mech->log_in_ok($user->email);

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'dummyuk' ],
        COBRAND_FEATURES => {
            reopening_disallowed => {
                dummyuk => 1,
            },
        },
    }, sub {
        $mech->get_ok('/report/' . $report->id);
        $mech->content_lacks("This problem has not been fixed");
    };

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'fixmystreet' ],
        COBRAND_FEATURES => {
            reopening_disallowed => {
                fixmystreet => {
                    DummyFMS => 1,
                }
            },
        },
    }, sub {
        $mech->get_ok('/report/' . $report->id);
        $mech->content_lacks("This problem has not been fixed");
    };
};

done_testing;
