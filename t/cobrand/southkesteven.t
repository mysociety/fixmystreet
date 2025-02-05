use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $south_kesteven = $mech->create_body_ok(2380, 'South Kesteven District Council', { cobrand => 'southkesteven' });
my $contact = $mech->create_contact_ok( body_id => $south_kesteven->id, category => 'Graffiti', email => 'graffiti@example.org' );
my $standard_user = $mech->create_user_ok( 'user@email.com', name => 'User' );

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'southkesteven',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        updates_allowed => {
            southkesteven => 'reporter/staff'
        }
    }
}, sub {
    my ($report) = $mech->create_problems_for_body(
        1,
        $south_kesteven->id,
        'A report',
        {   user     => $standard_user,
            category => 'Graffiti',
        },
    );

    subtest "Reporter can't close / fix an open report via an update" => sub {
        ok $report->is_open;
        $mech->log_in_ok( $standard_user->email );
        $mech->get_ok( '/report/' . $report->id );
        $mech->content_like(
            qr/textarea.*id="form_update"/,
            'can leave text update',
        );
        $mech->content_unlike(
            qr/select.*id="state"/,
            'no state dropdown',
        );
        $mech->content_unlike(
            qr/input.*id="form_fixed"/,
            'no checkbox for fixed',
        );
    };

    $report->update({ state => 'closed' });
    subtest "Reporter can reopen a closed report" => sub {
        ok !$report->is_open;
        $mech->get_ok( '/report/' . $report->id );

        $mech->content_like(
            qr/textarea.*id="form_update"/,
            'can leave text update',
        );
        $mech->content_unlike(
            qr/select.*id="state"/,
            'no state dropdown',
        );
        $mech->content_like(
            qr/input.*id="form_reopen"/,
            'has checkbox for reopen',
        );
    };
};

done_testing();
