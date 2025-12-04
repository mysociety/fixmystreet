use FixMyStreet::TestMech;

ok( my $mech = FixMyStreet::TestMech->new, 'Created mech object' );

my $hounslow_id = $mech->create_body_ok(2483, 'Hounslow Highways', { cobrand => 'hounslow' })->id;
$mech->create_contact_ok(
    body_id => $hounslow_id,
    category => 'Potholes',
    email => 'pothole@example.org',
);

my $user = $mech->create_user_ok('staff@example.org', from_body => $hounslow_id);
$user->user_body_permissions->create({ body_id => $hounslow_id, permission_type => 'user_edit' });

my $tfl = $mech->create_body_ok( 2483, 'TfL');
$mech->create_contact_ok(
    body_id => $tfl->id,
    category => 'Traffic lights',
    email => 'tfl@example.org',
);

$mech->create_problems_for_body(1, $hounslow_id, 'An old problem made before Hounslow FMS launched', {
    created => '2018-12-25 09:00',
    confirmed => '2018-12-25 09:00',
    lastupdate => '2018-12-25 09:00',
    latitude => 51.482286,
    longitude => -0.328163,

});
$mech->create_problems_for_body(1, $hounslow_id, 'A brand new problem made on the Hounslow site', {
    latitude => 51.482286,
    longitude => -0.328163,
    cobrand => 'hounslow'
});
my ($report) = $mech->create_problems_for_body(1, $hounslow_id, 'A brand new problem made on fixmystreet.com', {
    latitude => 51.482286,
    longitude => -0.328163,
    external_id => 'ABC123',
    cobrand => 'fixmystreet'
});

subtest "it still shows old reports on fixmystreet.com" => sub {
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'fixmystreet',
    }, sub {
        $mech->get_ok('/reports/Hounslow');

        $mech->content_contains('An old problem made before Hounslow FMS launched');
        $mech->content_contains('A brand new problem made on the Hounslow site');
        $mech->content_contains('A brand new problem made on fixmystreet.com');
    };
};

subtest "it does not show old reports on Hounslow" => sub {
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'hounslow',
    }, sub {
        $mech->get_ok('/reports/Hounslow');
        $mech->content_lacks('An old problem made before Hounslow FMS launched');
        $mech->content_contains('A brand new problem made on the Hounslow site') or diag $mech->content;
        $mech->content_contains('A brand new problem made on fixmystreet.com');
    };
};

subtest "it shows the right things on an /around page" => sub {
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'hounslow',
    }, sub {
        $mech->get_ok('/around?pc=TW7+5JN');
        $mech->content_lacks('An old problem made before Hounslow FMS launched');
        $mech->content_contains('A brand new problem made on the Hounslow site') or diag $mech->content;
        $mech->content_contains('A brand new problem made on fixmystreet.com');
    };
};

subtest "Shows external ID on report page to staff users only" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'hounslow',
    }, sub {
        $mech->get_ok('/report/' . $report->id);
        $mech->content_lacks('ABC123');
        $mech->log_in_ok('staff@example.org');
        $mech->get_ok('/report/' . $report->id);
        $mech->content_contains('ABC123');
    };
};

subtest "Admin searches right domains" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'hounslow',
    }, sub {
        foreach ('hounslowhighways.org', 'hounslow.gov.uk') {
            $mech->get_ok('/admin/users?search=xyz@' . $_);
            $mech->content_contains('xyz@' . $_);
        }
    };
};

$mech->log_out_ok;

for my $cobrand ( "hounslow", "fixmystreet") {
    subtest "Doesn't allow update to change report status on $cobrand cobrand" => sub {
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => $cobrand,
            COBRAND_FEATURES => {
                update_states_disallowed => {
                    fixmystreet => {
                        Hounslow => 1,
                    },
                    hounslow => 1,
                }
            },
        }, sub {
            $report->update({ state => "confirmed" });
            $mech->get_ok('/report/' . $report->id);
            $mech->content_lacks('form_fixed');

            $report->update({ state => "closed" });
            $mech->get_ok('/report/' . $report->id);
            $mech->content_lacks('form_reopen');
        };
    };
}

done_testing();
