use LWP::Protocol::PSGI;

use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

use t::Mock::Nominatim;

# check that we can get the page
$mech->get_ok('/alert');
$mech->title_like(qr/^Email alerts & RSS/);
$mech->content_contains('Subscribe to email alerts for problems in the area you care about');
$mech->content_contains('html class="no-js" lang="en-gb"');

# check that we can get list page
FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ { 'fixmystreet' => '.' } ],
    MAPIT_URL => 'http://mapit.uk/',
    GEOCODER => '',
}, sub {
    $mech->get_ok('/alert/list');
    $mech->title_like(qr/^Email alerts & RSS/);
    # No postcode provided, so we get redirected back to /alert/index.html
    $mech->content_contains('Subscribe to email alerts for problems in the area you care about');
    $mech->content_contains('html class="no-js" lang="en-gb"');

    $mech->get_ok('/alert/list?pc=EH1+1BB');
    $mech->title_like(qr/^Email alerts & RSS/);
    # Got a postcode this time, so we are asked for alert config options
    $mech->content_contains('Which problems do you want alerts about?');
    $mech->content_contains('html class="no-js" lang="en-gb"');
    $mech->content_like(qr/Problems within [0-9.]+km of EH1 1BB/);
    $mech->content_contains('Problems within Edinburgh City');
    $mech->content_contains('Problems within City Centre ward');
    $mech->content_contains('council:2651:Edinburgh');
    $mech->content_contains('ward:2651:20728:Edinburgh:City_Centre');
    $mech->content_contains('And where should your alerts be delivered?');
    $mech->content_contains('Subscribe by email');

    $mech->get_ok('/alert/list?pc=EH1+1BB&delivery=rss');
    $mech->title_like(qr/^Email alerts & RSS/);
    $mech->content_contains('Which problems do you want alerts about?');
    $mech->content_like(qr/Problems within [0-9.]+km of EH1 1BB/);
    $mech->content_contains('Problems within Edinburgh City');
    $mech->content_contains('Problems within City Centre ward');
    # Asked for RSS feeds this time!
    $mech->content_lacks('And where should your alerts be delivered?');
    $mech->content_contains('Grab your RSS feed');
    $mech->content_contains('js-alerts-rss-live-preview');

    subtest "Test Nominatim lookup" => sub {
        LWP::Protocol::PSGI->register(t::Mock::Nominatim->run_if_script, host => 'nominatim.openstreetmap.org');
        $mech->get_ok('/alert/list?pc=High Street');
        $mech->content_contains('We found more than one match for that location');
    };

    $mech->get_ok('/alert/list?pc=');
    $mech->title_like(qr/^Email alerts & RSS/);
    $mech->content_contains('Subscribe to email alerts for problems in the area you care about');

    $mech->get_ok('/alert/list?pc=GL502PR');
    $mech->content_contains('Reports near GL50 2PR are sent to different councils');
    $mech->content_contains('Problems within the boundary of');
    $mech->content_contains('area:2326:Cheltenham');
    $mech->content_contains('area:2226:Gloucestershire');
    $mech->content_contains('Or problems reported to');
    $mech->content_contains('council:2326:Cheltenham');
    $mech->content_contains('council:2226:Gloucestershire');
    $mech->content_contains('And where should your alerts be delivered?');
    $mech->content_contains('Subscribe by email');

    $mech->get_ok('/alert/subscribe?type=local&pc=ky16+8yg&rss=Give+me+an+RSS+feed&rznvy=' );
    $mech->content_contains('Please select the feed you want');

    $mech->get_ok('/alert/subscribe?feed=invalid:1000:A_Location&type=local&pc=ky16+8yg&rss=Give+me+an+RSS+feed&rznvy=');
    $mech->content_contains('Illegal feed selection');

    $mech->create_body_ok(2504, 'Birmingham City Council');
    $mech->create_body_ok(2226, 'Gloucestershire County Council');
    $mech->create_body_ok(2326, 'Cheltenham Borough Council');

    $mech->get_ok('/alert/subscribe?rss=Give+me+an+RSS+feed&feed=area:1000:Birmingham');
    is $mech->uri->path, '/rss/reports/Birmingham';

    $mech->get_ok('/alert/subscribe?rss=Give+me+an+RSS+feed&feed=area:1000:1001:Cheltenham:Lansdown');
    is $mech->uri->path, '/rss/area/Cheltenham/Lansdown';

    $mech->get_ok('/alert/subscribe?rss=Give+me+an+RSS+feed&feed=council:1000:Gloucestershire');
    is $mech->uri->path, '/rss/reports/Gloucestershire';

    $mech->get_ok('/alert/subscribe?rss=Give+me+an+RSS+feed&feed=ward:1000:1001:Cheltenham:Lansdown');
    is $mech->uri->path, '/rss/reports/Cheltenham/Lansdown';
};

done_testing();
