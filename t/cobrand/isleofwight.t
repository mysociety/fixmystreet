use FixMyStreet::TestMech;

ok( my $mech = FixMyStreet::TestMech->new, 'Created mech object' );

my $isleofwight_id = $mech->create_body_ok(2636, 'Isle of Wight Council')->id;
$mech->create_contact_ok(
    body_id => $isleofwight_id,
    category => 'Potholes',
    email => 'pothole@example.org',
);

my $user = $mech->create_user_ok('user@example.org');

my @reports = $mech->create_problems_for_body(1, $isleofwight_id, 'An Isle of wight report', {
    confirmed => '2019-05-25 09:00',
    lastupdate => '2019-05-25 09:00',
    latitude => 50.7108,
    longitude => -1.29573,
    user => $user
});

subtest "only original reporter can comment" => sub {
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'isleofwight',
    }, sub {
        $mech->get_ok('/report/' . $reports[0]->id);
        $mech->content_contains('Only the original reporter may leave updates');

        $mech->log_in_ok('user@example.org');
        $mech->get_ok('/report/' . $reports[0]->id);
        $mech->content_lacks('Only the original reporter may leave updates');
    };
};


done_testing();
