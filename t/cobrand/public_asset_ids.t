use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

# Test with an arbitrary cobrand
my $pbro_body = $mech->create_body_ok( 2566, 'Peterborough City Council', { cobrand => 'peterborough' } );

my %problem_params = (
    latitude  => 52.5608,
    longitude => 0.2405,
    cobrand   => 'peterborough',
);

my ($problem_pbro_tree)
    = $mech->create_problems_for_body( 1, $pbro_body->id,
    'Tree problem', \%problem_params, );
$problem_pbro_tree->external_id('€0123');
$problem_pbro_tree->set_extra_metadata( customer_reference => 'TREE123' );
$problem_pbro_tree->update_extra_field(
    { name => 'tree_code', value => 101 } );
$problem_pbro_tree->whensent( $problem_pbro_tree->confirmed );
$problem_pbro_tree->update;

my ($problem_pbro_bin)
    = $mech->create_problems_for_body( 1, $pbro_body->id,
    'Bin problem', \%problem_params, );
$problem_pbro_bin->external_id('€0234');
$problem_pbro_bin->set_extra_metadata( customer_reference => 'BIN234' );
$problem_pbro_bin->update_extra_field(
    { name => 'central_asset_id', value => 201 }, );
$problem_pbro_bin->whensent( $problem_pbro_bin->confirmed );
$problem_pbro_bin->update;

my ($problem_pbro_other)
    = $mech->create_problems_for_body( 1, $pbro_body->id, 'Other problem',
    \%problem_params, );
$problem_pbro_other->external_id('€0345');
$problem_pbro_other->set_extra_metadata( customer_reference => 'OTH345' );
$problem_pbro_other->update_extra_field( { name => 'other_id', value => 301 },
);
$problem_pbro_other->whensent( $problem_pbro_other->confirmed );
$problem_pbro_other->update;

subtest 'Single public asset ID defined' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'peterborough', 'fixmystreet' ],
        COBRAND_FEATURES =>
            { public_asset_ids => { peterborough => ['tree_code'] } },
        MAPIT_URL => 'http://mapit.uk/',
        },
        sub {
        # Reports should display the same info on both cobrands
        for my $host ( 'peterborough.fixmystreet.com', 'www.fixmystreet.com' )
        {
            subtest "$host handles external IDs/refs correctly" => sub {
                ok $mech->host($host);

                note 'tree_code:';
                $mech->get_ok( '/report/' . $problem_pbro_tree->id );
                $mech->content_lacks( $problem_pbro_tree->external_id,
                    'External ID not shown' );
                $mech->content_lacks(
                    'Council ref:</strong> TREE123',
                    'Council reference not shown',
                );
                $mech->content_contains( 'Asset ID:</strong> 101',
                    'Asset ID is shown' );

                note 'central_asset_id:';
                $mech->get_ok( '/report/' . $problem_pbro_bin->id );
                $mech->content_lacks( $problem_pbro_bin->external_id,
                    'External ID not shown' );
                $mech->content_lacks(
                    'Council ref:</strong> BIN234',
                    'Council reference not shown',
                );
                $mech->content_lacks( 'Asset ID:</strong> 201',
                    'Asset ID not shown' );

                note 'no code:';
                $mech->get_ok( '/report/' . $problem_pbro_other->id );
                $mech->content_lacks( $problem_pbro_other->external_id,
                    'External ID not shown' );
                $mech->content_lacks(
                    'Council ref:</strong> OTH345',
                    'Council reference not shown',
                );
                $mech->content_lacks( 'Asset ID:</strong> 301',
                    'Asset ID not shown' );
            };
        }
        };
};

subtest 'Multiple public asset IDs defined' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'peterborough', 'fixmystreet' ],
        COBRAND_FEATURES => {
            public_asset_ids =>
                { peterborough => [ 'tree_code', 'central_asset_id' ] },
        },
        MAPIT_URL => 'http://mapit.uk/',
        },
        sub {
        # Reports should display the same info on both cobrands
        for my $host ( 'peterborough.fixmystreet.com', 'www.fixmystreet.com' )
        {
            subtest "$host handles external IDs/refs correctly" => sub {
                ok $mech->host($host);

                note 'tree_code:';
                $mech->get_ok( '/report/' . $problem_pbro_tree->id );
                $mech->content_lacks( $problem_pbro_tree->external_id,
                    'External ID not shown' );
                $mech->content_lacks(
                    'Council ref:</strong> TREE123',
                    'Council reference not shown',
                );
                $mech->content_contains( 'Asset ID:</strong> 101',
                    'Asset ID is shown' );

                note 'central_asset_id:';
                $mech->get_ok( '/report/' . $problem_pbro_bin->id );
                $mech->content_lacks( $problem_pbro_bin->external_id,
                    'External ID not shown' );
                $mech->content_lacks(
                    'Council ref:</strong> BIN234',
                    'Council reference not shown',
                );
                $mech->content_contains( 'Asset ID:</strong> 201',
                    'Asset ID is shown' );

                note 'no code:';
                $mech->get_ok( '/report/' . $problem_pbro_other->id );
                $mech->content_lacks( $problem_pbro_other->external_id,
                    'External ID not shown' );
                $mech->content_lacks(
                    'Council ref:</strong> OTH345',
                    'Council reference not shown',
                );
                $mech->content_lacks( 'Asset ID:</strong> 301',
                    'Asset ID not shown' );

                # If a report has extra fields that match both
                # public_asset_ids, we should choose the first match
                my ($problem_pbro_conflict)
                    = $mech->create_problems_for_body( 1, $pbro_body->id,
                    'We have a problem',
                    \%problem_params );
                $problem_pbro_conflict->external_id('€0987');
                $problem_pbro_conflict->set_extra_metadata(
                    customer_reference => 'CON987' );
                $problem_pbro_conflict->update_extra_field(
                    { name => 'tree_code', value => 101 } );
                $problem_pbro_conflict->update_extra_field(
                    { name => 'central_asset_id', value => 201 } );
                $problem_pbro_conflict->whensent(
                    $problem_pbro_conflict->confirmed );
                $problem_pbro_conflict->update;

                note 'conflicting codes:';
                $mech->get_ok( '/report/' . $problem_pbro_conflict->id );
                $mech->content_lacks( $problem_pbro_conflict->external_id,
                    'External ID not shown' );
                $mech->content_lacks(
                    'Council ref:</strong> CON987',
                    'Council reference not shown',
                );
                $mech->content_contains( 'Asset ID:</strong> 101',
                    'First matching asset ID is shown' );
            };
        }
        };
};

subtest 'public_asset_ids not defined' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'peterborough', 'fixmystreet' ],
        MAPIT_URL        => 'http://mapit.uk/',
        },
        sub {
        # Reports should display the same info on both cobrands
        for my $host ( 'peterborough.fixmystreet.com', 'www.fixmystreet.com' )
        {
            subtest "$host handles external IDs/refs correctly" => sub {
                ok $mech->host($host);

                note 'tree_code:';
                $mech->get_ok( '/report/' . $problem_pbro_tree->id );
                $mech->content_lacks( $problem_pbro_tree->external_id,
                    'External ID not shown' );
                $mech->content_lacks(
                    'Council ref:</strong> TREE123',
                    'Council reference not shown',
                );
                $mech->content_lacks( 'Asset ID:</strong> 101',
                    'Asset ID not shown' );

                note 'central_asset_id:';
                $mech->get_ok( '/report/' . $problem_pbro_bin->id );
                $mech->content_lacks( $problem_pbro_bin->external_id,
                    'External ID not shown' );
                $mech->content_lacks(
                    'Council ref:</strong> BIN234',
                    'Council reference not shown',
                );
                $mech->content_lacks( 'Asset ID:</strong> 201',
                    'Asset ID not shown' );

                note 'no code:';
                $mech->get_ok( '/report/' . $problem_pbro_other->id );
                $mech->content_lacks( $problem_pbro_other->external_id,
                    'External ID not shown' );
                $mech->content_lacks(
                    'Council ref:</strong> OTH345',
                    'Council reference not shown',
                );
                $mech->content_lacks( 'Asset ID:</strong> 301',
                    'Asset ID not shown' );
            };
        }
        };
};

done_testing;
