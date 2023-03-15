use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

FixMyStreet::override_config { ALLOWED_COBRANDS => ['gloucestershire'] },
    sub {
    ok $mech->host('gloucestershire'), 'change host to gloucestershire';
    $mech->get_ok('/');
    $mech->content_like(qr/Enter a Gloucestershire postcode/);
};

done_testing();
