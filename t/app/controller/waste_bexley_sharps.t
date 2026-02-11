use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.uk/',
    ALLOWED_COBRANDS => 'bexley',
    COBRAND_FEATURES => {
        waste => { bexley => 1 },
        waste_features => {
            bexley => {
                sharps_enabled => 1,
            },
        },
    },
}, sub {
    subtest 'Eligible property can access sharps booking form' => sub {
        # XXX
        ok 1;
    };
};

done_testing;
