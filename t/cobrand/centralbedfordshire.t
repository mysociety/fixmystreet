use CGI::Simple;
use Test::MockModule;
use Test::MockTime qw(:all);
use File::Temp 'tempdir';
use FixMyStreet::TestMech;
use FixMyStreet::Script::Alerts;
use FixMyStreet::Script::Reports;
use Catalyst::Test 'FixMyStreet::App';
use FixMyStreet::Script::CSVExport;

FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

use_ok 'FixMyStreet::Cobrand::CentralBedfordshire';

my $ukc = Test::MockModule->new('FixMyStreet::Cobrand::UKCouncils');
$ukc->mock('_fetch_features', sub {
    my ($self, $cfg, $x, $y) = @_;
    is $y, 238194, 'Correct latitude';
    return [
        {
            properties => { streetref1 => 'Road ID' },
            geometry => {
                type => 'LineString',
                coordinates => [ [ $x-2, $y+2 ], [ $x+2, $y+2 ] ],
            }
        },
        # regression test to ensure that a closer feature with no streetref1
        # isn't picked for NSGRef.
        {
            properties => { streetref1 => '' },
            geometry => {
                type => 'LineString',
                coordinates => [ [ $x-1, $y-1 ], [ $x+1, $y-1 ] ],
            }
        },
    ];
});

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(21070, 'Central Bedfordshire Council', {
    send_method => 'Open311', api_key => 'key', 'endpoint' => 'e', 'jurisdiction' => 'j', cobrand => 'centralbedfordshire' });
$mech->create_contact_ok(body_id => $body->id, category => 'Bridges', email => "BRIDGES");
$mech->create_contact_ok(body_id => $body->id, category => 'Cleaning Contract Reports', email => "CLEANING");
$mech->create_contact_ok(body_id => $body->id, category => 'Potholes', email => "POTHOLES");
$mech->create_contact_ok(body_id => $body->id, category => 'Jadu', email => "Jadu");

my $normal_user = $mech->create_user_ok('test@example.net', name => 'Normal User');
my $staffuser = $mech->create_user_ok('counciluser@example.com', name => 'Council User',
    from_body => $body, password => 'password');

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

    subtest 'Correct area_code and NSGRef parameters for Open311' => sub {
        $report->set_extra_fields({ name => 'UnitID', value => 'Asset 123' });
        $report->update;
        FixMyStreet::Script::Reports::send();
        my $req = Open311->test_req_used;
        my $c = CGI::Simple->new($req->content);
        is $c->param('service_code'), 'BRIDGES';
        is $c->param('attribute[area_code]'), 'Area1';
        is $c->param('attribute[NSGRef]'), 'Road ID';
        is $c->param('attribute[title]'),  $report->title;
        (my $c_description = $c->param('attribute[description]')) =~ s/\r\n/\n/g;
        is $c_description, $report->detail . "\n\nUnit ID: Asset 123";
        is $c->param('attribute[report_url]'),  "http://centralbedfordshire.example.org/report/" . $report->id;
        is $c->param('attribute[UnitID]'), undef, 'Unit ID not included as attribute';
        like $c->param('description'), qr/Unit ID: Asset 123/, 'But is included in description';

        $mech->email_count_is(1);
        $report->discard_changes;
        like $mech->get_text_body_from_email, qr/reference number is @{[$report->external_id]}/;
        unlike $report->detail, qr/Unit ID: Asset 123/, 'Asset ID not left in description';
    };

    subtest 'External ID is shown on report page' => sub {
        $mech->get_ok('/report/' . $report->id);
        $mech->content_contains("Council ref:&nbsp;" . $report->external_id);
    };

    subtest "it doesn't show old reports on the cobrand" => sub {
        $mech->create_problems_for_body(1, $body->id, 'An old problem made before Central Beds FMS launched', {
            state => 'fixed - user',
            created => '2018-12-25 09:00',
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

        FixMyStreet::Script::Reports::send();
        my $req = Open311->test_req_used;
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

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'centralbedfordshire' ],
    MAPIT_URL => 'http://mapit.uk/',
    STAGING_FLAGS => { send_reports => 1, skip_checks => 0 },
}, sub {
    subtest "it doesn't send report logged or update emails for Jadu categories" => sub {
        $mech->clear_emails_ok();

        $mech->log_in_ok( $normal_user->email );
        $mech->get_ok('/report/new?latitude=52.03553&longitude=-0.36067');
        $mech->submit_form_ok({
            with_fields => {
                title => 'Jadu no emails test.',
                detail => 'Jadu no emails test detail.',
                category => 'Jadu',
            }
        });

        FixMyStreet::Script::Reports::send();
        $mech->email_count_is(0);

        my $report = FixMyStreet::DB->resultset('Problem')->find( { title => "Jadu no emails test." } );
        FixMyStreet::DB->resultset('Comment')->find_or_create(
            {
                problem_id => $report->id,
                user_id    => $staffuser->id,
                name       => 'Staff',
                mark_fixed => 'false',
                text       => 'This is some update text',
                state      => 'confirmed',
            }
        );
        FixMyStreet::Script::Alerts::send_updates();
        $mech->email_count_is(0);
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


subtest 'Dashboard CSV extra columns' => sub {
    my $UPLOAD_DIR = tempdir( CLEANUP => 1 );
    $mech->log_in_ok( $staffuser->email );
    $report->update_extra_field({ name => 'Type', value => ['Furniture', 'Bin bags'] });
    $report->update_extra_field({ name => 'Issue', value => 'Cobwebs' });
    $report->update;
    my ($cleaning) = $mech->create_problems_for_body(1, $body->id, 'Cleaning Test Report', {
        category => 'Cleaning Contract Reports', cobrand => 'centralbedfordshire',
        latitude => 52.030695, longitude => -0.357033, areas => ',117960,11804,135257,148868,21070,37488,44682,59795,65718,83582,',
    });
    $cleaning->update_extra_field({ name => 'Issue', value => 'Cobwebs' });
    $cleaning->update;
    FixMyStreet::override_config {
        MAPIT_URL => 'http://mapit.uk/',
        ALLOWED_COBRANDS => 'centralbedfordshire',
        PHOTO_STORAGE_OPTIONS => { UPLOAD_DIR => $UPLOAD_DIR },
    }, sub {
        $mech->get_ok('/dashboard?export=1');
        $mech->content_contains('"Site Used","Reported As",CRNo,"Fly-tipping types","Cleaning types"');
        $mech->content_contains('centralbedfordshire,,' . $report->external_id . ',"Bin bags;Furniture"');
        $mech->content_contains(',centralbedfordshire,,,,Cobwebs');
        FixMyStreet::Script::CSVExport::process(dbh => FixMyStreet::DB->schema->storage->dbh);
        $mech->get_ok('/dashboard?export=1');
        $mech->content_contains('"Site Used","Reported As",CRNo,"Fly-tipping types","Cleaning types"');
        $mech->content_contains('centralbedfordshire,,' . $report->external_id . ',"Bin bags;Furniture"');
        $mech->content_contains(',centralbedfordshire,,,,Cobwebs');
    }
};


done_testing();
