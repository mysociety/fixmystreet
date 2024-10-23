use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

use Test::MockModule;
use t::Mock::Nominatim;

# check that we can get the page
$mech->get_ok('/alert');
$mech->title_like(qr/^Local RSS feeds and email alerts/);
$mech->content_contains('Local RSS feeds and email alerts');
$mech->content_contains('html class="no-js" lang="en-gb"');
$mech->create_body_ok(2651, 'TfL');
$mech->create_body_ok(2651, 'National Highways');
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
    $mech->content_contains('rss/pc/EH11BB');
    $mech->content_contains('All reports within Edinburgh City');
    $mech->content_contains('All reports within City Centre ward');
    $mech->content_contains('/rss/area/2651');
    $mech->content_contains('/rss/area/20728');
    $mech->content_contains('area:2651', 'Council feed contains Edinburgh id and details');
    $mech->content_contains('area:20728', 'Ward feed contains Edinburgh id and details');

    subtest "Test Nominatim lookup" => sub {
        $mech->get_ok('/alert/list?pc=High Street');
        $mech->content_contains('We found more than one match for that location');
    };

    $mech->get_ok('/alert/list?pc=');
    $mech->content_contains('To find out what local alerts we have for you');

    # Two-tier council
    $mech->get_ok('/alert/list?pc=GL502PR');
    $mech->content_contains('Problems in an area');

    $mech->get_ok('/alert/subscribe?rss=1&type=local&pc=EH1+1BB&rss=Give+me+an+RSS+feed&rznvy=' );
    $mech->content_contains('Please select the feed you want');

    $mech->get_ok('/alert/subscribe?rss=1&feed=invalid:1000:A_Locationtype=local&pc=EH1+1BB&rss=Give+me+an+RSS+feed&rznvy=');
    $mech->content_contains('Illegal feed selection');

    $mech->get_ok('/alert/subscribe?rss=1&feed=area:1000');
    is $mech->uri->path, '/rss/area/1000';

    $mech->get_ok('/alert/subscribe?rss=1&feed=area:1001');
    is $mech->uri->path, '/rss/area/1001';

    $mech->get_ok('/alert/subscribe?rss=1&feed=council:1000:Gloucestershire');
    is $mech->uri->path, '/rss/reports/Gloucestershire';

    $mech->get_ok('/alert/subscribe?rss=1&feed=ward:1000:1001:Cheltenham:Lansdown');
    is $mech->uri->path, '/rss/reports/Cheltenham/Lansdown';
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'fixmystreet',
    MAPIT_URL => 'http://mapit.uk/',
    GEOCODER => '',
    RECAPTCHA => { secret => 'secret', site_key => 'site_key' },
}, sub {
    subtest 'recaptcha' => sub {
        $mech->get_ok('/alert/list?pc=EH11BB');
        $mech->content_lacks('g-recaptcha'); # GB is default test country

        my $mod_app = Test::MockModule->new('FixMyStreet::App');
        $mod_app->mock('user_country', sub { 'FR' });
        my $mod_lwp = Test::MockModule->new('LWP::UserAgent');
        $mod_lwp->mock('post', sub { HTTP::Response->new(200, 'OK', [], '{ "success": true }') });

        $mech->get_ok('/alert/list?pc=EH11BB');
        $mech->content_contains('g-recaptcha');
        $mech->submit_form_ok({ with_fields => { rznvy => 'someone@example.org' } });
    };
};

done_testing();
