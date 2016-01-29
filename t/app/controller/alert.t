use strict;
use warnings;
use Test::More;
use LWP::Protocol::PSGI;

use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

use t::Mock::Nominatim;

# check that we can get the page
$mech->get_ok('/alert');
$mech->title_like(qr/^Local RSS feeds and email alerts/);
$mech->content_contains('Local RSS feeds and email alerts');
$mech->content_contains('html class="no-js" lang="en-gb"');

# check that we can get list page
FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ { 'fixmystreet' => '.' } ],
    MAPIT_URL => 'http://mapit.mysociety.org/',
    GEOCODER => '',
}, sub {
    $mech->get_ok('/alert/list');
    $mech->title_like(qr/^Local RSS feeds and email alerts/);
    $mech->content_contains('Local RSS feeds and email alerts');
    $mech->content_contains('html class="no-js" lang="en-gb"');

    $mech->get_ok('/alert/list?pc=EH99 1SP');
    $mech->title_like(qr/^Local RSS feeds and email alerts/);
    $mech->content_contains('Here are the types of local problem alerts for &lsquo;EH99&nbsp;1SP&rsquo;');
    $mech->content_contains('html class="no-js" lang="en-gb"');
    $mech->content_contains('Problems within 8.5km');
    $mech->content_contains('rss/pc/EH991SP/2');
    $mech->content_contains('rss/pc/EH991SP/5');
    $mech->content_contains('rss/pc/EH991SP/10');
    $mech->content_contains('rss/pc/EH991SP/20');
    $mech->content_contains('Problems within City of Edinburgh');
    $mech->content_contains('Problems within City Centre ward');
    $mech->content_contains('/rss/reports/City+of+Edinburgh');
    $mech->content_contains('/rss/reports/City+of+Edinburgh/City+Centre');
    $mech->content_contains('council:2651:City_of_Edinburgh');
    $mech->content_contains('ward:2651:20728:City_of_Edinburgh:City_Centre');

    subtest "Test Nominatim lookup" => sub {
        LWP::Protocol::PSGI->register(t::Mock::Nominatim->run_if_script, host => 'nominatim.openstreetmap.org');
        $mech->get_ok('/alert/list?pc=High Street');
        $mech->content_contains('We found more than one match for that location');
    };

    $mech->get_ok('/alert/list?pc=');
    $mech->content_contains('To find out what local alerts we have for you');

    $mech->get_ok('/alert/list?pc=GL502PR');
    $mech->content_contains('Problems within the boundary of');

    $mech->get_ok('/alert/subscribe?rss=1&type=local&pc=ky16+8yg&rss=Give+me+an+RSS+feed&rznvy=' );
    $mech->content_contains('Please select the feed you want');

    $mech->get_ok('/alert/subscribe?rss=1&feed=invalid:1000:A_Locationtype=local&pc=ky16+8yg&rss=Give+me+an+RSS+feed&rznvy=');
    $mech->content_contains('Illegal feed selection');

    $mech->create_body_ok(2504, 'Birmingham City Council');
    $mech->create_body_ok(2226, 'Gloucestershire County Council');
    $mech->create_body_ok(2326, 'Cheltenham Borough Council');

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
