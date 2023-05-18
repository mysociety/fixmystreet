use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

FixMyStreet::override_config { ALLOWED_COBRANDS => ['gloucestershire'] },
    sub {
    ok $mech->host('gloucestershire'), 'change host to gloucestershire';
    $mech->get_ok('/');
    $mech->content_like(qr/Enter a Gloucestershire postcode/);

    my $cobrand = FixMyStreet::Cobrand::Gloucestershire->new;
    for my $string (
        'Gloucester Road, Tewkesbury',
        '  gloucester  rd,tewkesbury  ',
    ) {
        is $cobrand->disambiguate_location($string)->{town},
            'Gloucestershire, GL20 5XA',
            'variation of example search location is disambiguated';
    }
};

done_testing();
