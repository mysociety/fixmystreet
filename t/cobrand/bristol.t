use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

# Create test data
my $body = $mech->create_body_ok( 2561, 'Bristol County Council', {
    send_method => 'Open311',
    can_be_devolved => 1
});

my $open311_contact = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Street Lighting',
    email => 'LIGHT',
);
my $email_contact = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Potholes',
    email => 'potholes@example.org',
    send_method => 'Email'
);

subtest 'Only Open311 categories are shown on Bristol cobrand', sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'bristol' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->get_ok("/report/new/ajax?latitude=51.494885&longitude=-2.602237");
        $mech->content_contains($open311_contact->category);
        $mech->content_lacks($email_contact->category);
    };
};

subtest 'All categories are shown on FMS cobrand', sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'fixmystreet' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        $mech->get_ok("/report/new/ajax?latitude=51.494885&longitude=-2.602237");
        $mech->content_contains($open311_contact->category);
        $mech->content_contains($email_contact->category);
    };
};

done_testing();
