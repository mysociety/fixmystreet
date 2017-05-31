use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'hart' ],
}, sub {
    ok $mech->host("hart.fixmystreet.com"), "change host to hart";
    $mech->get_ok('/');
    $mech->content_like( qr/Hart\b/ );
};

done_testing();
