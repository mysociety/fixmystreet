use CGI::Simple;
use Test::MockModule;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Alerts;
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

my @reports = $mech->create_problems_for_body( 1, $body->id, 'Test', {
    category => 'Zebra Crossing',
});
my $report = $reports[0];

my $alert = FixMyStreet::DB->resultset("Alert")->create({
    alert_type => 'new_updates',
    cobrand => 'cheshireeast',
    parameter => $report->id,
    user => {
        email => 'alert@example.com',
        email_verified => 1,
    },
});
$alert->confirm;

$mech->create_comment_for_problem($report, $report->user, $report->name, 'blah', 0, 'confirmed', 'confirmed', {
    confirmed => \'current_timestamp'
});

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
        my $test_data = FixMyStreet::Script::Reports::send();
        $report->discard_changes;
        ok $report->whensent, 'Report marked as sent';
        is $report->send_method_used, 'Open311', 'Report sent via Open311';
        is $report->external_id, 248, 'Report has right external ID';

        my $req = $test_data->{test_req_used};
        my $c = CGI::Simple->new($req->content);
        is $c->param('attribute[title]'), 'Test Test 1 for ' . $body->id, 'Request had correct title';
    };

    subtest 'testing reference numbers shown' => sub {
        $mech->get_ok('/report/' . $report->id);
        $mech->content_contains('Council ref:&nbsp;' . $report->id);
        FixMyStreet::Script::Alerts::send();
        like $mech->get_text_body_from_email, qr/reference number is @{[$report->id]}/;
    };

    subtest 'contact page blocked', sub {
        $mech->get('/contact');
        is $mech->res->code, 404;
    };

    subtest 'check post-submission message', sub {
        $mech->log_in_ok($report->user->email);
        $mech->get_ok('/report/new?latitude=53.145324&longitude=-2.370437');
        $mech->submit_form_ok({ with_fields => {
            title => 'title',
            detail => 'detail',
        }});
        my $report = FixMyStreet::DB->resultset('Problem')->search(undef, { order_by => { -desc => 'id' } })->single;
        $mech->content_contains('please call us on 0300 123 5020, quoting your reference number ' . $report->id);
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
