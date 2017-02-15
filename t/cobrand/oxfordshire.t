use strict;
use warnings;
use Test::More;

use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

subtest 'check /ajax defaults to open reports only' => sub {
    my $categories = [ 'Bridges', 'Fences', 'Manhole' ];
    my $params = {
        postcode  => 'OX28 4DS',
        latitude  =>  51.7847208192,
        longitude => -1.49445264029,
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
            $mech->create_problems_for_body( 1, 2237, 'Around page', \%report_params );
        }
    }

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { 'oxfordshire' => '.' } ],
        MAPIT_URL => 'http://mapit.mysociety.org/',
    }, sub {
        my $json = $mech->get_ok_json( '/ajax?status=all&bbox=' . $bbox );
        my $pins = $json->{pins};
        is scalar @$pins, 6, 'correct number of reports created';

        $json = $mech->get_ok_json( '/ajax?bbox=' . $bbox );
        $pins = $json->{pins};
        is scalar @$pins, 3, 'correct number of reports returned with no filters';

        $json = $mech->get_ok_json( '/ajax?filter_category=Fences&bbox=' . $bbox );
        $pins = $json->{pins};
        is scalar @$pins, 1, 'only one Fences report by default';
    }
};

my $superuser = $mech->create_user_ok('superuser@example.com', name => 'Super User', is_superuser => 1);

subtest 'Exor RDI download appears on Oxfordshire cobrand admin' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { 'oxfordshire' => '.' } ],
    }, sub {
        $mech->log_in_ok( $superuser->email );
        $mech->get_ok('/admin');
        $mech->content_contains("Download Exor RDI");
    }
};

subtest 'Exor RDI download doesn’t appear outside of Oxfordshire cobrand admin' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ { 'fixmystreet' => '.' } ],
    }, sub {
        $mech->log_in_ok( $superuser->email );
        $mech->get_ok('/admin');
        $mech->content_lacks("Download Exor RDI");
    }
};

# Clean up
$mech->delete_user( $superuser );
$mech->delete_problems_for_body( 2237 );
done_testing();
