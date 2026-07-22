use CGI::Simple;
use Test::MockModule;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

use_ok 'FixMyStreet::Cobrand::Dudley';

my $ukc = Test::MockModule->new('FixMyStreet::Cobrand::UKCouncils');
$ukc->mock('_fetch_features', sub {
    my ($self, $cfg, $x, $y) = @_;
    is $y, 290704, 'Correct latitude';
    return [
        {
            properties => { usrn => 'Road ID' },
            geometry => {
                type => 'LineString',
                coordinates => [ [ $x-2, $y+2 ], [ $x+2, $y+2 ] ],
            }
        },
    ];
});

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2522, 'Dudley Borough Council', {
    send_method => 'Open311', api_key => 'key', 'endpoint' => 'e', 'jurisdiction' => 'j', cobrand => 'dudley', send_comments => 1, blank_updates_permitted => 1, can_be_devolved => 1 });
$mech->create_contact_ok(body_id => $body->id, category => 'Bridges', email => 'bridges@example.org', send_method => 'Email');
$mech->create_contact_ok(body_id => $body->id, category => 'Potholes', email => "Potholes");

my ($report) = $mech->create_problems_for_body(1, $body->id, 'Test Report', {
    category => 'Potholes', cobrand => 'dudley',
    latitude => 52.5142, longitude => -2.08, areas => ',2522,169375,169852,164864,',
});

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'dudley',
    MAPIT_URL => 'http://mapit.uk/',
    STAGING_FLAGS => { send_reports => 1, skip_checks => 0 },
    COBRAND_FEATURES => {
        open311_email => {
            dudley => {
                Potholes => 'potholes@example.org',
            }
        }
    },
}, sub {
    subtest 'cobrand displays council name' => sub {
        ok $mech->host("dudley.fixmystreet.com"), "change host to dudley";
        $mech->get_ok('/');
        $mech->content_contains('Dudley');
    };

    subtest 'cobrand does not display email categories' => sub {
        $mech->get_ok('/report/new?latitude=52.5142&longitude=-2.08');
        $mech->content_contains('Potholes');
        $mech->content_lacks('Bridges');
    };

    subtest 'Correct NSGRef parameters for Open311' => sub {
        FixMyStreet::Script::Reports::send();
        my $req = Open311->test_req_used;
        my $c = CGI::Simple->new($req->content);
        is $c->param('service_code'), 'Potholes';
        is $c->param('attribute[NSGRef]'), 'Road ID';
        is $c->param('attribute[report_url]'),  "http://dudley.example.org/report/" . $report->id;
        like $c->param('description'), qr/@{[$report->title]}/;

        $mech->email_count_is(2);
        my @emails = $mech->get_email;
        ok scalar(grep {
            $_->header('To') eq 'FixMyStreet <potholes@example.org>'
        } @emails), 'email sent to configured address';
    };
};

done_testing;
