use JSON::MaybeXS;
use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

# Check old .cgi links redirect correctly
$mech->get_ok('/open311.cgi/v2/requests.rss?jurisdiction_id=fiksgatami.no&status=open&agency_responsible=1854');
like $mech->uri, qr[/open311/v2/requests\.rss\?.{65}]; # Don't know order parameters will be in now

$mech->create_problems_for_body(2, 2237, 'Around page');
$mech->get_ok('/open311/v2/requests.xml?jurisdiction_id=foo&status=open&agency_responsible=2237');
$mech->content_contains('<description>Around page Test 2 for 2237: Around page Test 2 for 2237 Detail</description>');
$mech->content_contains('<interface_used>Web interface</interface_used>');
$mech->content_contains('<status>open</status>');

$mech->get_ok('/open311/v2/requests.json?jurisdiction_id=foo&status=open&agency_responsible=2237');
my $json = decode_json($mech->content);
my $problems = $json->{requests}[0]{request};
is @$problems, 2;
like $problems->[0]{description}, qr/Around page Test/;

done_testing();
