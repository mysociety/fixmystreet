use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'lincolnshire',
}, sub {
    subtest "custom homepage text" => sub {
        $mech->get_ok('/');
        $mech->content_contains('like potholes, broken paving slabs, or street lighting');
    };
};

done_testing();
