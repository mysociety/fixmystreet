use CGI::Simple;
use Test::MockModule;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok( 21069, 'Cheshire East Council', {
    send_method => 'Open311',
    endpoint => 'endpoint',
    api_key => 'key',
    jurisdiction => 'cheshireeast_confirm',
});

my $contact = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Zebra Crossing',
    email => 'ZEBRA',
);

my $cobrand = Test::MockModule->new('FixMyStreet::Cobrand::CheshireEast');
$cobrand->mock('_fetch_features', sub {
    return [];
});

use_ok 'FixMyStreet::Cobrand::CheshireEast';

FixMyStreet::override_config {
    COBRAND_FEATURES => {
        contact_email => {
            cheshireeast => 'foo@cheshireeast',
        }
    },
}, sub {
    my $cobrand = FixMyStreet::Cobrand::CheshireEast->new;
    like $cobrand->contact_email, qr/cheshireeast/;
    is_deeply $cobrand->disambiguate_location->{bounds}, [ 52.947150, -2.752929, 53.387445, -1.974789 ];
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'cheshireeast',
    MAPIT_URL => 'http://mapit.uk/',
    STAGING_FLAGS => { skip_checks => 1, send_reports => 1 },
}, sub {

    subtest 'cobrand displays council name' => sub {
        ok $mech->host("cheshireeast.fixmystreet.com"), "change host to cheshireeast";
        $mech->get_ok('/');
        $mech->content_contains('Cheshire East');
    };

    subtest 'testing special Open311 behaviour', sub {
        my @reports = $mech->create_problems_for_body( 1, $body->id, 'Test', {
            category => 'Zebra Crossing',
        });
        my $report = $reports[0];

        my $test_data = FixMyStreet::Script::Reports::send();
        $report->discard_changes;
        ok $report->whensent, 'Report marked as sent';
        is $report->send_method_used, 'Open311', 'Report sent via Open311';
        is $report->external_id, 248, 'Report has right external ID';

        my $req = $test_data->{test_req_used};
        my $c = CGI::Simple->new($req->content);
        is $c->param('attribute[title]'), 'Test Test 1 for ' . $body->id, 'Request had correct title';
    };

    subtest 'contact page blocked', sub {
        $mech->get('/contact');
        is $mech->res->code, 404;
    };

    subtest 'checking alert pages', sub {
        $mech->get_ok('/alert');
        $mech->content_contains('all reported problems');
        $mech->submit_form_ok({ with_fields => { pc => 'CW11 1HZ' } });
        $mech->content_contains('Reported problems within 10.0km');
        $mech->content_contains('All reported problems');
        $mech->content_contains('Reported problems within Sandbach Town');
    };
};

done_testing();
