use Test::MockModule;

use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

my $oxon = $mech->create_body_ok(2237, 'Oxfordshire County Council');

subtest 'check /around?ajax defaults to open reports only' => sub {
    my $categories = [ 'Bridges', 'Fences', 'Manhole' ];
    my $params = {
        postcode  => 'OX28 4DS',
        cobrand => 'oxfordshire',
        latitude  =>  51.784721,
        longitude => -1.494453,
    };
    my $bbox = ($params->{longitude} - 0.01) . ',' .  ($params->{latitude} - 0.01)
                . ',' . ($params->{longitude} + 0.01) . ',' .  ($params->{latitude} + 0.01);

    # Create one open and one fixed report in each category
    foreach my $category ( @$categories ) {
        foreach my $state ( 'confirmed', 'fixed' ) {
            my %report_params = (
                %$params,
                category => $category,
                state => $state,
            );
            $mech->create_problems_for_body( 1, $oxon->id, 'Around page', \%report_params );
        }
    }

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { 'oxfordshire' => '.' } ],
    }, sub {
        my $json = $mech->get_ok_json( '/around?ajax=1&status=all&bbox=' . $bbox );
        my $pins = $json->{pins};
        is scalar @$pins, 6, 'correct number of reports created';

        $json = $mech->get_ok_json( '/around?ajax=1&bbox=' . $bbox );
        $pins = $json->{pins};
        is scalar @$pins, 3, 'correct number of reports returned with no filters';

        $json = $mech->get_ok_json( '/around?ajax=1&filter_category=Fences&bbox=' . $bbox );
        $pins = $json->{pins};
        is scalar @$pins, 1, 'only one Fences report by default';
    }
};

my @problems = FixMyStreet::DB->resultset('Problem')->search({}, { rows => 3 })->all;

subtest 'can use customer reference to search for reports' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'oxfordshire' ],
        MAPIT_URL => 'http://mapit.uk/',
    }, sub {
        my $problem = $problems[0];
        $problem->set_extra_metadata( customer_reference => 'ENQ12456' );
        $problem->update;

        $mech->get_ok('/around?pc=ENQ12456');
        is $mech->uri->path, '/report/' . $problem->id, 'redirects to report';
    };
};

END {
    done_testing();
}
