use FixMyStreet::TestMech;
use Test::MockModule;

my $mech = FixMyStreet::TestMech->new;

# Mock tilma so TfL's report_new_is_on_tlrn method doesn't make a live API call.
use t::Mock::Tilma;
my $tilma = t::Mock::Tilma->new;
LWP::Protocol::PSGI->register( $tilma->to_psgi_app,
    host => 'tilma.mysociety.org' );

my $cobrand = Test::MockModule->new('FixMyStreet::Cobrand::Southwark');

$cobrand->mock('estate_feature_for_point', sub {
    my ( $self, $lat, $lon ) = @_;
    if ($lat eq "51.50352") {
        # inside an estate
        return {
                properties => {
                    Site_code => "PHAU12345"
                }
            };
    }
});


use constant SOUTHWARK_AREA_ID => 2491;

my $southwark = $mech->create_body_ok(
    SOUTHWARK_AREA_ID,
    'Southwark Council',
    { cobrand => 'southwark' },
);

$mech->create_contact_ok(
    body_id  => $southwark->id,
    category => 'Abandoned Bike (Street)',
    email    => 'STCL_ABBI',
);
$mech->create_contact_ok(
    body_id  => $southwark->id,
    category => 'Abandoned Bike (Estate)',
    email    => 'HOU_ABBI',
);

my $tfl = $mech->create_body_ok( SOUTHWARK_AREA_ID, 'TfL' );
my $river_piers = $mech->create_contact_ok(
    body_id  => $tfl->id,
    category => 'River Piers',
    email    => 'tfl@example.org',
);
$river_piers->set_extra_metadata( group => ['River Piers'] );
$river_piers->update;
my $bus_stops = $mech->create_contact_ok(
    body_id  => $tfl->id,
    category => 'Bus Stops and Shelters',
    email    => 'tfl@example.org',
);
$bus_stops->set_extra_metadata( group => ['Bus Stops and Shelters'] );
$bus_stops->update;


FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'southwark', 'tfl' ],
    MAPIT_URL        => 'http://mapit.uk/',
}, sub {
    subtest "Correct categories shown on street" => sub {
        ok $mech->host('southwark.fixmystreet.com'), 'set host';

        my $json = $mech->get_ok_json(
            '/report/new/ajax?longitude=-0.08051&latitude=51.50351');

        is_deeply $json->{by_category} => {
            'Abandoned Bike (Street)' => {
                allow_anonymous => 'true',
                bodies => ['Southwark Council'],
            },
            'Bus Stops and Shelters' => {
                allow_anonymous => 'true',
                bodies => ['TfL'],
            },
        }, "Southwark 'street' area doesn't have River Piers category";

    };

    subtest "Correct categories shown on estate" => sub {
        ok $mech->host('southwark.fixmystreet.com'), 'set host';

        my $json = $mech->get_ok_json(
            '/report/new/ajax?longitude=-0.08052&latitude=51.50352');

        is_deeply $json->{by_category} => {
            'Abandoned Bike (Estate)' => {
                allow_anonymous => 'true',
                bodies => ['Southwark Council'],
            },
        }, "Southwark 'estate' area doesn't have TfL categories or street category";

    };
};

done_testing;
