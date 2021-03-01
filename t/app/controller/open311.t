use JSON::MaybeXS;
use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2237 => 'Oxfordshire');
my $body_id = $body->id;
$mech->create_contact_ok(body_id => $body_id, category => 'Open doors', email => 'OD');

my ($problem1, $problem2) = $mech->create_problems_for_body(2, $body_id, 'Around page');
$mech->get_ok('/open311/v2/requests.xml?jurisdiction_id=foo&status=open&agency_responsible=' . $body_id);
$mech->content_contains("<description>Around page Test 2 for $body_id: Around page Test 2 for $body_id Detail</description>");
$mech->content_contains('<interface_used>Web interface</interface_used>');
$mech->content_contains('<status>open</status>');

$mech->get_ok('/open311/v2/discovery.xml');

$mech->get_ok('/open311/v2/services.xml?jurisdiction_id=foo');
$mech->content_contains('<service_name>Open doors</service_name>');

my $json = $mech->get_ok_json('/open311/v2/services.json?jurisdiction_id=foo');
is $json->{services}[0]{service_name}, 'Open doors';

$json = $mech->get_ok_json('/open311/v2/requests.json?jurisdiction_id=foo&status=open&agency_responsible=' . $body_id);
my $problems = $json->{service_requests};
is @$problems, 2;
like $problems->[0]{description}, qr/Around page Test/;

subtest "non_public reports aren't available" => sub {
    $problem1->update({
        non_public => 1,
        detail => 'This report is now private',
    });
    $json = $mech->get_ok_json('/open311/v2/requests.json?jurisdiction_id=foo');
    $problems = $json->{service_requests};
    is @$problems, 1;
    like $problems->[0]{description}, qr/Around page Test/;
    $mech->content_lacks('This report is now private');

    my $problem_id = $problem1->id;
    $json = $mech->get_ok_json("/open311/v2/requests/$problem_id.json?jurisdiction_id=foo");
    $problems = $json->{service_requests};
    is @$problems, 0;
};

subtest "hidden reports aren't available" => sub {
    $problem1->update({
        non_public => 0,
        detail => 'This report is now hidden',
        state => "hidden",
    });
    $json = $mech->get_ok_json('/open311/v2/requests.json?jurisdiction_id=foo');
    $problems = $json->{service_requests};
    is @$problems, 1;
    like $problems->[0]{description}, qr/Around page Test/;
    $mech->content_lacks('This report is now hidden');

    my $problem_id = $problem1->id;
    $json = $mech->get_ok_json("/open311/v2/requests/$problem_id.json?jurisdiction_id=foo");
    $problems = $json->{service_requests};
    is @$problems, 0;
};

subtest "Zurich open311 docs differ from main docs" => sub {
    $mech->get_ok('/open311');
    $mech->content_contains('agency_responsible');
    $mech->content_contains('list of services provided for WGS84 coordinate latitude 60 longitude 11');
    $mech->content_contains('&lt;description&gt;Mangler brustein');

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'zurich',
    }, sub {
        ok $mech->host("www.zueriwieneu.ch"), 'host to zueriwieneu';
        $mech->get_ok('/open311');
        $mech->content_lacks('agency_responsible');
        $mech->content_contains('list of services provided for WGS84 coordinate latitude 47.3 longitude 8.5');
        $mech->content_contains('&lt;description&gt;Unebener');
    };
};

done_testing();
