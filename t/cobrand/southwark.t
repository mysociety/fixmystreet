use FixMyStreet::TestMech;
use Test::MockModule;

my $mech = FixMyStreet::TestMech->new;

# Mock tilma so TfL's report_new_is_on_tlrn method doesn't make a live API call.
use t::Mock::Tilma;
my $tilma = t::Mock::Tilma->new;
LWP::Protocol::PSGI->register( $tilma->to_psgi_app,
    host => 'tilma.mysociety.org' );

use constant SOUTHWARK_AREA_ID => 2491;

my $southwark = $mech->create_body_ok(
    SOUTHWARK_AREA_ID,
    'Southwark Council',
    {},
    { cobrand => 'southwark' },
);

$mech->create_contact_ok(
    body_id  => $southwark->id,
    category => 'Abandoned Bike (Street)',
    email    => 'STCL_ABBI',
);

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'southwark', 'tfl' ],
    MAPIT_URL        => 'http://mapit.uk/',
}, sub {
    subtest "hides the TfL River Piers category" => sub {
        my $tfl = $mech->create_body_ok( SOUTHWARK_AREA_ID, 'TfL' );
        my $river_piers = $mech->create_contact_ok(
            body_id  => $tfl->id,
            category => 'River Piers',
            email    => 'tfl@example.org',
        );
        $river_piers->set_extra_metadata( group => ['River Piers'] );
        $river_piers->update;

        ok $mech->host('southwark.fixmystreet.com'), 'set host';

        my $json = $mech->get_ok_json(
            '/report/new/ajax?longitude=-0.08051&latitude=51.50351');

        is_deeply $json->{by_category} => {
            'Abandoned Bike (Street)' => {
                allow_anonymous => 'true',
                bodies => ['Southwark Council'],
            },
        }, "Southwark 'street' area doesn't have River Piers category";

        # TODO Estates
    };
};

done_testing;
