use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

use t::Mock::Nominatim;

# check that we can get the page
$mech->get_ok('/alert');
$mech->title_like(qr/^Local RSS feeds and email alerts/);
$mech->content_contains('Local RSS feeds and email alerts');
$mech->content_contains('html class="no-js" lang="en-gb"');

my $body = $mech->create_body_ok(2651, 'Edinburgh');
$mech->create_body_ok(2504, 'Birmingham City Council');
$mech->create_body_ok(2226, 'Gloucestershire County Council');
$mech->create_body_ok(2326, 'Cheltenham Borough Council');

# check that we can get list page
FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ { 'fixmystreet' => '.' } ],
    MAPIT_URL => 'http://mapit.uk/',
    GEOCODER => '',
}, sub {
    $mech->get_ok('/alert/list');
    $mech->title_like(qr/^Local RSS feeds and email alerts/);
    $mech->content_contains('Local RSS feeds and email alerts');
    $mech->content_contains('html class="no-js" lang="en-gb"');

    $mech->get_ok('/alert/list?pc=EH1 1BB');
    $mech->title_like(qr/^Local RSS feeds and email alerts/);
    $mech->content_like(qr/Local RSS feeds and email alerts for .EH1 1BB/);
    $mech->content_contains('html class="no-js" lang="en-gb"');
    $mech->content_contains('Problems within 10.0km');
    $mech->content_contains('rss/pc/EH11BB/2');
    $mech->content_contains('rss/pc/EH11BB/5');
    $mech->content_contains('rss/pc/EH11BB/10');
    $mech->content_contains('rss/pc/EH11BB/20');
    $mech->content_contains('Problems within Edinburgh City');
    $mech->content_contains('Problems within City Centre ward');
    $mech->content_contains('/rss/reports/Edinburgh');
    $mech->content_contains('/rss/reports/Edinburgh/City+Centre');
    $mech->content_contains('council:' . $body->id . ':Edinburgh');
    $mech->content_contains('ward:' . $body->id . ':20728:Edinburgh:City_Centre');

    subtest "Test Nominatim lookup" => sub {
        $mech->get_ok('/alert/list?pc=High Street');
        $mech->content_contains('We found more than one match for that location');
    };

    $mech->get_ok('/alert/list?pc=');
    $mech->content_contains('To find out what local alerts we have for you');

    # Two-tier council
    $mech->get_ok('/alert/list?pc=GL502PR');
    $mech->content_contains('Problems in an area');
    $mech->content_contains('Reports by destination');

    $mech->get_ok('/alert/subscribe?rss=1&type=local&pc=EH1+1BB&rss=Give+me+an+RSS+feed&rznvy=' );
    $mech->content_contains('Please select the feed you want');

    $mech->get_ok('/alert/subscribe?rss=1&feed=invalid:1000:A_Locationtype=local&pc=EH1+1BB&rss=Give+me+an+RSS+feed&rznvy=');
    $mech->content_contains('Illegal feed selection');

    $mech->get_ok('/alert/subscribe?rss=1&feed=area:1000:Birmingham');
    is $mech->uri->path, '/rss/reports/Birmingham';

    $mech->get_ok('/alert/subscribe?rss=1&feed=area:1000:1001:Cheltenham:Lansdown');
    is $mech->uri->path, '/rss/area/Cheltenham/Lansdown';

    $mech->get_ok('/alert/subscribe?rss=1&feed=council:1000:Gloucestershire');
    is $mech->uri->path, '/rss/reports/Gloucestershire';

    $mech->get_ok('/alert/subscribe?rss=1&feed=ward:1000:1001:Cheltenham:Lansdown');
    is $mech->uri->path, '/rss/reports/Cheltenham/Lansdown';
};

done_testing();
