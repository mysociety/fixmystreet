use Test::MockModule;
use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

# Mock tilma so TfL's report_new_is_on_tlrn method doesn't make a live API call.
use t::Mock::Tilma;
my $tilma = t::Mock::Tilma->new;
LWP::Protocol::PSGI->register($tilma->to_psgi_app, host => 'tilma.mysociety.org');

use constant CAMDEN_MAPIT_ID => 2505;

my $camden = $mech->create_body_ok(CAMDEN_MAPIT_ID, 'Camden Council', {}, {
    cobrand => 'camden'
});

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'camden', 'tfl' ],
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    subtest "hides the TfL River Piers category" => sub {
        $mech->create_contact_ok(body_id => $camden->id, category => 'Potholes', email => 'potholes@camden.fixmystreet.com');

        my $tfl = $mech->create_body_ok(CAMDEN_MAPIT_ID, 'TfL');
        $mech->create_contact_ok(body_id => $tfl->id, category => 'River Piers', email => 'tfl@example.org');

        ok $mech->host('camden.fixmystreet.com'), 'set host';

        my $json = $mech->get_ok_json('/report/new/ajax?latitude=51.529432&longitude=-0.124514');
        is_deeply $json->{by_category}, { 'Potholes' => { 'bodies' => [ 'Camden Council' ] } }, "Camden doesn't have River Piers category";
    };
};

done_testing;
