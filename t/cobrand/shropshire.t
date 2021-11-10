use CGI::Simple;
use Test::MockModule;
use Test::MockTime qw(:all);
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use Catalyst::Test 'FixMyStreet::App';


my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2238, 'Shropshire Council');
$mech->create_contact_ok(body_id => $body->id, category => 'Bridges', email => 'bridges@example.org');

my ($report) = $mech->create_problems_for_body(1, $body->id, 'Test Report', {
    category => 'Bridges', cobrand => 'shropshire',
    latitude => 52.859331, longitude => -3.054912, areas => ',11809,129425,144013,144260,148857,2238,39904,47098,66017,95047,',
    external_id => '1309813', whensent => \'current_timestamp',
});

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'shropshire' ],
    MAPIT_URL => 'http://mapit.uk/',
    STAGING_FLAGS => { send_reports => 1, skip_checks => 0 },
}, sub {

    subtest 'cobrand displays council name' => sub {
        ok $mech->host("shropshire.fixmystreet.com"), "change host to shropshire";
        $mech->get_ok('/');
        $mech->content_contains('Shropshire Council');
    };

    subtest 'cobrand displays council name' => sub {
        $mech->get_ok('/reports/Shropshire');
        $mech->content_contains('Shropshire Council');
    };

    subtest 'External ID is shown on report page' => sub {
        $mech->get_ok('/report/' . $report->id);
        $mech->content_contains("Council ref:&nbsp;" . $report->external_id);
    };

};

done_testing();
