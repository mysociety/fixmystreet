use FixMyStreet::TestMech;
use Test::MockModule;

my $mech = FixMyStreet::TestMech->new;

my %lat_lons = (
    public_default       => [ 51,   -1 ],
    private_leased       => [ 51.5, -1 ],
    public_adopted_roads => [ 52,   -1 ],
    private_default      => [ 52.5, -1 ],
);

my $mock_pbro = Test::MockModule->new('FixMyStreet::Cobrand::Peterborough');
$mock_pbro->mock(
    _fetch_features => sub {
        my ( $self, $args, $x, $y ) = @_;

        if ( $x =~ /^470/ && $args->{url} =~ m{4/query} ) {
            # Lat 50, lon 1
            # Council land - public
            return [ { geometry => { type => 'Point' } } ];
        }
        elsif ( $x =~ /^469/ && $args->{url} =~ m{3/query} ) {
            # Lat 51, lon 2
            # Leased-out council land - counts as private
            return [ { geometry => { type => 'Point' } } ];
        }
        elsif ( $x =~ /^468/ && $args->{url} =~ m{7/query} ) {
            # Lat 52, lon 3
            # Adopted roads - public
            return [ { geometry => { type => 'Point' } } ];
        }

        return [];
    }
);

subtest 'Peterborough' => sub {
    my $peterborough
        = $mech->create_body_ok( 2566, 'Peterborough City Council' );

    FixMyStreet::override_config {
        MAPIT_URL        => 'http://mapit.uk/',
        ALLOWED_COBRANDS => [ 'fixmystreet', 'peterborough' ],
    } => sub {
        for my $test (
            { category => 'General fly tipping' },
            { category => 'Non offensive graffiti' }
            )
        {
            my $cat = $test->{category};

            subtest "$cat reported on Peterborough site" => sub {
                my $contact = $mech->create_contact_ok(
                    email    => 'ABC',
                    body_id  => $peterborough->id,
                    category => $cat,
                );

                my ($problem) = $mech->create_problems_for_body(
                    1,
                    $peterborough->id,
                    "$cat on Peterborough",
                    {   category  => $cat,
                        latitude  => $lat_lons{public_default}[0],
                        longitude => $lat_lons{public_default}[1],
                        cobrand   => 'peterborough',
                        areas     => ',2566,',
                    },
                );

                is $problem->get_cobrand_logged->land_type_for_problem(
                    $problem),
                    'public', 'land_type should be public';

                $problem->latitude( $lat_lons{private_leased}[0] );
                $problem->longitude( $lat_lons{private_leased}[1] );
                is $problem->get_cobrand_logged->land_type_for_problem(
                    $problem),
                    'public', 'land_type should not be updated yet';
                $problem->update;
                is $problem->get_cobrand_logged->land_type_for_problem(
                    $problem),
                    'private', 'land_type should be updated to private';

                $problem->latitude( $lat_lons{public_adopted_roads}[0] );
                $problem->longitude( $lat_lons{public_adopted_roads}[1] );
                $problem->update;
                is $problem->get_cobrand_logged->land_type_for_problem(
                    $problem),
                    'public', 'land_type should be updated to public';

                $problem->latitude( $lat_lons{private_default}[0] );
                $problem->longitude( $lat_lons{private_default}[1] );
                $problem->update;
                is $problem->get_cobrand_logged->land_type_for_problem(
                    $problem),
                    'private', 'land_type should be updated to private';
            };
        }

        subtest 'Category that is not graffiti or fly-tipping' => sub {
            my $cat = 'Bins';

            my $contact = $mech->create_contact_ok(
                email    => 'ABC',
                body_id  => $peterborough->id,
                category => $cat,
            );

            my ($problem) = $mech->create_problems_for_body(
                1,
                $peterborough->id,
                "$cat on Peterborough",
                {   category  => $cat,
                    latitude  => $lat_lons{public_default}[0],
                    longitude => $lat_lons{public_default}[1],
                    cobrand   => 'peterborough',
                    areas     => ',2566,',
                },
            );

            is $problem->get_cobrand_logged->land_type_for_problem($problem),
                '', 'land_type should be empty string';
        };

        subtest 'Peterborough fly-tipping reported on fixmystreet' => sub {
            my $cat = 'General fly tipping';

            my $contact = $mech->create_contact_ok(
                email    => 'ABC',
                body_id  => $peterborough->id,
                category => $cat,
            );

            my ($problem) = $mech->create_problems_for_body(
                1,
                $peterborough->id,
                "Peterborough fly-tipping on FMS",
                {   category  => $cat,
                    latitude  => $lat_lons{public_default}[0],
                    longitude => $lat_lons{public_default}[1],
                    cobrand   => 'fixmystreet',
                    areas     => ',2566,',
                },
            );

            is $problem->get_cobrand_logged->land_type_for_problem($problem),
                'public', 'land_type should be public';
        };
    };
};

subtest 'Another cobrand' => sub {
    my $bexley = $mech->create_body_ok( 2494, 'London Borough of Bexley' );

    my $cat = 'General fly tipping';

    my $contact = $mech->create_contact_ok(
        email    => 'ABC',
        body_id  => $bexley->id,
        category => $cat,
    );

    FixMyStreet::override_config {
        MAPIT_URL        => 'http://mapit.uk/',
        ALLOWED_COBRANDS => [ 'fixmystreet', 'bexley' ],
    } => sub {
        subtest "Fly-tipping reported on Bexley site" => sub {

            my ($problem) = $mech->create_problems_for_body(
                1,
                $bexley->id,
                "Fly-tipping on Bexley",
                {   category  => $cat,
                    latitude  => $lat_lons{public_default}[0],
                    longitude => $lat_lons{public_default}[1],
                    cobrand   => 'bexley',
                    areas     => ',2494,',
                },
            );

            is $problem->get_cobrand_logged->land_type_for_problem($problem),
                undef, 'land_type should be undef';
            $problem->latitude( $lat_lons{private_leased}[0] );
            $problem->longitude( $lat_lons{private_leased}[1] );
            ok $problem->update, 'Update OK';
        };

        subtest 'Bexley fly-tipping reported on fixmystreet' => sub {
            my ($problem) = $mech->create_problems_for_body(
                1,
                $bexley->id,
                "Fly-tipping on Bexley",
                {   category  => $cat,
                    latitude  => $lat_lons{public_default}[0],
                    longitude => $lat_lons{public_default}[1],
                    cobrand   => 'fixmystreet',
                    areas     => ',2494,',
                },
            );

            is $problem->get_cobrand_logged->land_type_for_problem($problem),
                undef, 'land_type should be undef';
            $problem->latitude( $lat_lons{private_leased}[0] );
            $problem->longitude( $lat_lons{private_leased}[1] );
            ok $problem->update, 'Update OK';
        };
    };
};

done_testing;
