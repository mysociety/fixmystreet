use CGI::Simple;
use Test::MockModule;
use Test::MockTime qw(:all);
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use Catalyst::Test 'FixMyStreet::App';

use_ok 'FixMyStreet::Cobrand::CentralBedfordshire';

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(21070, 'Central Bedfordshire Council', {
    send_method => 'Open311', api_key => 'key', 'endpoint' => 'e', 'jurisdiction' => 'j' });
$mech->create_contact_ok(body_id => $body->id, category => 'Bridges', email => "BRIDGES");
$mech->create_contact_ok(body_id => $body->id, category => 'Potholes', email => "POTHOLES");

my ($report) = $mech->create_problems_for_body(1, $body->id, 'Test Report', {
    category => 'Bridges', cobrand => 'centralbedfordshire',
    latitude => 52.030695, longitude => -0.357033, areas => ',117960,11804,135257,148868,21070,37488,44682,59795,65718,83582,',
});

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'centralbedfordshire' ],
    MAPIT_URL => 'http://mapit.uk/',
    STAGING_FLAGS => { send_reports => 1, skip_checks => 0 },
    COBRAND_FEATURES => {
        area_code_mapping => { centralbedfordshire => {
            59795 => 'Area1',
            60917 => 'Area2',
            60814 => 'Area3',
        } },
        open311_email => { centralbedfordshire => {
            Potholes => 'potholes@example.org',
        } }
    },
}, sub {

    subtest 'cobrand displays council name' => sub {
        ok $mech->host("centralbedfordshire.fixmystreet.com"), "change host to centralbedfordshire";
        $mech->get_ok('/');
        $mech->content_contains('Central Bedfordshire');
    };

    subtest 'cobrand displays council name' => sub {
        $mech->get_ok('/reports/Central+Bedfordshire');
        $mech->content_contains('Central Bedfordshire');
    };

    subtest 'Correct area_code parameter for Open311' => sub {
        my $test_data = FixMyStreet::Script::Reports::send();
        my $req = $test_data->{test_req_used};
        my $c = CGI::Simple->new($req->content);
        is $c->param('service_code'), 'BRIDGES';
        is $c->param('attribute[area_code]'), 'Area1';

        $mech->email_count_is(1);
        $report->discard_changes;
        like $mech->get_text_body_from_email, qr/reference number is @{[$report->external_id]}/;
    };

    subtest 'External ID is shown on report page' => sub {
        $mech->get_ok('/report/' . $report->id);
        $mech->content_contains("Council ref:&nbsp;" . $report->external_id);
    };

    subtest "it doesn't show old reports on the cobrand" => sub {
        $mech->create_problems_for_body(1, $body->id, 'An old problem made before Central Beds FMS launched', {
            state => 'fixed - user',
            confirmed => '2018-12-25 09:00',
            lastupdate => '2018-12-25 09:00',
            latitude => 52.030692,
            longitude => -0.357032
        });

        $mech->get_ok('/reports/Central+Bedfordshire');
        $mech->content_lacks('An old problem made before Central Beds FMS launched');
    };

    subtest "it sends email as well as Open311 submission" => sub {
        my ($report2) = $mech->create_problems_for_body(1, $body->id, 'Another Report', {
            category => 'Potholes', cobrand => 'centralbedfordshire',
            latitude => 52.030695, longitude => -0.357033, areas => ',117960,11804,135257,148868,21070,37488,44682,59795,65718,83582,',
        });

        my $test_data = FixMyStreet::Script::Reports::send();
        my $req = $test_data->{test_req_used};
        my $c = CGI::Simple->new($req->content);
        is $c->param('service_code'), 'POTHOLES';

        $mech->email_count_is(2);
        $report2->discard_changes;
        my @emails = $mech->get_email;
        my$body = $mech->get_text_body_from_email($emails[0]);
        like $body, qr/A user of FixMyStreet has submitted the following report/;
        like $body, qr(http://centralbedfordshire.example.org/report/@{[$report2->id]});

        like $mech->get_text_body_from_email($emails[1]), qr/reference number is @{[$report2->external_id]}/;

    };
};

subtest "it still shows old reports on fixmystreet.com" => sub {
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'fixmystreet',
    }, sub {
        $mech->get_ok('/reports/Central+Bedfordshire?status=fixed');
        $mech->content_contains('An old problem made before Central Beds FMS launched');
    };
};

for my $cobrand ( "centralbedfordshire", "fixmystreet") {
    subtest "Doesn't allow update to change report status on $cobrand cobrand" => sub {
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => $cobrand,
            COBRAND_FEATURES => {
                update_states_disallowed => {
                    fixmystreet => {
                        "Central Bedfordshire" => 1,
                    },
                    centralbedfordshire => 1,
                }
            },
        }, sub {
            $report->update({ state => "confirmed" });
            $mech->get_ok('/report/' . $report->id);
            $mech->content_lacks('form_fixed');

            $report->update({ state => "closed" });
            $mech->get_ok('/report/' . $report->id);
            $mech->content_lacks('form_reopen');
        };
    };
}

subtest 'check geolocation overrides' => sub {
    my $cobrand = FixMyStreet::Cobrand::CentralBedfordshire->new;
    foreach my $test (
        { query => 'Clifton', town => 'Bedfordshire' },
        { query => 'Fairfield', town => 'Bedfordshire' },
    ) {
        my $res = $cobrand->disambiguate_location($test->{query});
        is $res->{town}, $test->{town}, "Town matches $test->{town}";
    }
};


done_testing();
