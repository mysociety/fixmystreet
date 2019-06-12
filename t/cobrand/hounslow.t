use FixMyStreet::TestMech;

ok( my $mech = FixMyStreet::TestMech->new, 'Created mech object' );

my $hounslow_id = $mech->create_body_ok(2483, 'Hounslow Borough Council')->id;
$mech->create_contact_ok(
    body_id => $hounslow_id,
    category => 'Potholes',
    email => 'pothole@example.org',
);

$mech->create_user_ok('staff@example.org', from_body => $hounslow_id);

my $tfl = $mech->create_body_ok( 2483, 'TfL');
$mech->create_contact_ok(
    body_id => $tfl->id,
    category => 'Traffic lights',
    email => 'tfl@example.org',
);

$mech->create_problems_for_body(1, $hounslow_id, 'An old problem made before Hounslow FMS launched', {
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

subtest "does not show TfL traffic lights category" => sub {
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'fixmystreet',
    }, sub {
        my $json = $mech->get_ok_json('/report/new/ajax?latitude=51.482286&longitude=-0.328163');
        is $json->{by_category}{"Traffic lights"}, undef;
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

done_testing();
