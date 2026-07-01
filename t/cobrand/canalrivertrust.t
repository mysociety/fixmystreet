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
            canalrivertrust => 'open/staff',
            fixmystreet     => {
                'Canal & River Trust' => 'open/staff',
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

            # Anyone can leave an update on an open report
            $report->update( { state => 'in progress' } );

            $mech->get_ok( '/report/' . $report->id );
            $mech->content_contains( 'Provide an update',
                'Can leave update on open report' );

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

            # Only staff can leave update on closed report
            $mech->get_ok( '/report/' . $report->id );
            if ( $user && $user->email eq $staff_user->email ) {
                $mech->content_contains( 'Provide an update',
                    'Can leave update on closed report' );
            } else {
                $mech->content_lacks( 'Provide an update',
                    'Cannot leave update on closed report' );
            }
        }
    }
};

done_testing();
