use FixMyStreet::TestMech;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $mech    = FixMyStreet::TestMech->new;
my $cobrand = FixMyStreet::Cobrand::CanalRiverTrust->new;
my $body    = $mech->create_body_ok(
    2226, # Same as for Gloucestershire for testing purposes
    'Canal & River Trust',
    {   send_method  => 'Email',
        cobrand => 'canalrivertrust',
    },
);

my $bad_boat = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Bad boat (CRT)',
    email => 'bad_boat@crt.dev',
);

my $standard_user_1
    = $mech->create_user_ok( 'user1@email.com', name => 'User 1' );
my $standard_user_2
    = $mech->create_user_ok( 'user2@email.com', name => 'User 2' );
my $staff_user = $mech->create_user_ok(
    'staff@email.com',
    name      => 'Staff User',
    from_body => $body,
);
$staff_user->user_body_permissions->create({ body => $body, permission_type => 'category_edit' });

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'fixmystreet', 'canalrivertrust' ],
    MAPIT_URL        => 'http://mapit.uk/',
    STAGING_FLAGS    => { skip_must_have_2fa => 1 },
    COBRAND_FEATURES => {
        update_states_disallowed => {
            canalrivertrust => 1,
            fixmystreet => {
                'Canal & River Trust' => 1,
            },
        },
        updates_allowed   => {
            canalrivertrust => 'none',
            fixmystreet     => {
                'Canal & River Trust' => 'none',
            }
        },
    },
}, sub {
    my ($report) = $mech->create_problems_for_body(
        1,
        $body->id,
        'My report',
        {   cobrand => 'canalrivertrust',
            user    => $standard_user_1,
            category => 'Bad boat',
        },
    );

    for my $host ( qw/fixmystreet canalrivertrust/ ) {
        ok $mech->host($host), "change host to $host";

        for my $user ( undef, $standard_user_1, $standard_user_2, $staff_user ) {
            $user ? $mech->log_in_ok( $user->email ) : $mech->log_out_ok;

            # No-one can leave an update on an open report
            $report->update( { state => 'in progress' } );

            $mech->get_ok( '/report/' . $report->id );
            $mech->content_lacks( 'Provide an update',
                'Cannot leave update on open report' );

            # Nobody can mark report as fixed
            $mech->content_lacks( 'This problem has been fixed',
                'Cannot mark report as fixed' );

            # No option to reopen report
            $report->update( { state => 'fixed' } );

            $mech->get_ok( '/report/' . $report->id );
            $mech->content_lacks(
                'This problem has not been fixed',
                'No option to reopen report',
            );

            # No-one can leave update on a closed report
            $mech->get_ok( '/report/' . $report->id );
            $mech->content_lacks( 'Provide an update',
                'Cannot leave update on closed report' );
        }
    }
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'canalrivertrust' ],
    MAPIT_URL        => 'http://mapit.uk/',
    COBRAND_FEATURES => {
    },
}, sub {
    $mech->get_ok( '/reports' );
    $mech->content_contains('Get updates of reports on the Canal & River Trust');
    $mech->content_lacks('class="has-inline-svg">Wards of this council');
    $mech->content_contains('href="/rss/reports/Canal+&amp;+River+Trust"');
    $mech->get_ok( '/rss/reports/Canal+&+River+Trust' ); # Browser decoded &amp;
    $mech->content_contains('New problems to Canal &amp; River Trust on Canal &amp; River Trust');
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'canalrivertrust' ],
    MAPIT_URL => 'http://mapit.uk/',
    BASE_URL => 'http://www.example.org',
    COBRAND_FEATURES => {
       category_groups => { canalrivertrust => 1 },
    }
}, sub {
    subtest 'Displays and protects category names' => sub {
        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/admin/body/' . $body->id);
        $mech->follow_link_ok({ text => 'Add new category' });
        $mech->content_contains('Parent categories');
        $mech->submit_form_ok( { with_fields => {
                                                 category => 'Access issues (CRT)',
                                                 group => 'Aqueduct',
                                                 email => 'AccessIssues@test.com',
                                                }
                               });
        $mech->content_contains('Category must end with (CRT: &lt;group_name&gt;)');
        $mech->submit_form_ok( { with_fields => {
                                                 category => 'Access issues (CRT: Aqueduct)',
                                                 group => 'Aqueduct',
                                                 email => 'AccessIssues@test.com',
                                                }
                               });
        $mech->content_contains('New category contact added');

        $mech->get_ok('/around');
        $mech->submit_form_ok( { with_fields => { pc => 'GL50 2PR' } },
            'submit location' );
        $mech->follow_link_ok(
            { text_regex => qr/skip this step/i, },
            "follow 'skip this step' link"
                             );

        $mech->content_contains('data-category_display="Access issues"');
    };
};

done_testing();
