use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

foreach my $council (qw/oxfordshire bromley/) {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ $council ],
    }, sub {
        ok $mech->host("$council.fixmystreet.com"), "change host to $council";
        $mech->get_ok('/');
        $mech->content_like( qr/\u$council/ );
    };
}

done_testing();
