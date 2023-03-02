use CGI::Simple;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use t::Mock::Tilma;
use Test::MockModule;
use Test::Output;

my $mech = FixMyStreet::TestMech->new;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $osm = Test::MockModule->new('FixMyStreet::Geocode');

$osm->mock('cache', sub {
    [
        {
          'osm_type' => 'way',
          'type' => 'tertiary',
          'display_name' => 'Engineers Way, London Borough of Brent, London, Greater London, England, HA9 0FJ, United Kingdom',
          'licence' => "Data \x{a9} OpenStreetMap contributors, ODbL 1.0. https://osm.org/copyright",
          'lat' => '51.55904',
          'importance' => '0.40001',
          'class' => 'highway',
          'place_id' => 216542819,
          'lon' => '-0.28168',
          'boundingbox' => [
                             '51.5585904',
                             '51.5586096',
                             '-0.2833485',
                             '-0.27861'
                           ],
          'osm_id' => 507095202
        },
        { # duplicate so we don't jump straight to report page with only one result
          'osm_type' => 'way',
          'type' => 'tertiary',
          'display_name' => 'Engineers Way, London Borough of Brent, London, Greater London, England, HA9 0FJ, United Kingdom',
          'licence' => "Data \x{a9} OpenStreetMap contributors, ODbL 1.0. https://osm.org/copyright",
          'lat' => '51.55904',
          'importance' => '0.40001',
          'class' => 'highway',
          'place_id' => 216542819,
          'lon' => '-0.28168',
          'boundingbox' => [
                             '51.5585904',
                             '51.5586096',
                             '-0.2833485',
                             '-0.27861'
                           ],
          'osm_id' => 507095202
        }
    ]
});

use_ok 'FixMyStreet::Cobrand::Brent';

my $super_user = $mech->create_user_ok('superuser@example.com', is_superuser => 1, name => "Super User");
my $comment_user = $mech->create_user_ok('comment@example.org', email_verified => 1, name => 'Brent');
my $brent = $mech->create_body_ok(2488, 'Brent', {
    api_key => 'abc',
    jurisdiction => 'brent',
    endpoint => 'http://endpoint.example.org',
    send_method => 'Open311',
    comment_user => $comment_user,
    send_extended_statuses => 1,
}, {
    cobrand => 'brent'
});
my $contact = $mech->create_contact_ok(body_id => $brent->id, category => 'Graffiti', email => 'graffiti@example.org');
my $gully = $mech->create_contact_ok(body_id => $brent->id, category => 'Gully grid missing',
    email => 'Symology-gully', group => ['Drains and gullies']);
my $user1 = $mech->create_user_ok('user1@example.org', email_verified => 1, name => 'User 1');

for my $test (
    {
        desc => 'Problem has stayed open when user reported fixed with update',
        report_status => 'confirmed',
        fields => { been_fixed => 'Yes', reported => 'No', another => 'No', update => 'Test' },
    },
    {
        desc => 'Problem has stayed open when user reported fixed without update',
        report_status => 'confirmed',
        fields => { been_fixed => 'Yes', reported => 'No', another => 'No' },
    },
    {
        desc => 'Problem has stayed fixed when user reported not fixed with update',
        report_status => 'fixed - council',
        fields => { been_fixed => 'No', reported => 'No', another => 'No', update => 'Test' },
    },
 ) { subtest "Response to questionnaire doesn't update problem state" => sub {
        my $dt = DateTime->now()->subtract( weeks => 5 );
        my $report_time = $dt->ymd . ' ' . $dt->hms;
        my $sent = $dt->add( minutes => 5 );
        my $sent_time = $sent->ymd . ' ' . $sent->hms;

        my ($problem) = $mech->create_problems_for_body(1, $brent->id, 'Title', {
        areas => "2488", category => 'Graffiti', cobrand => 'brent', user => $user1, confirmed => $report_time,
        lastupdate => $report_time, whensent => $sent_time, state => $test->{report_status}});


        FixMyStreet::override_config {
            ALLOWED_COBRANDS => 'brent',
        }, sub {

        FixMyStreet::DB->resultset('Questionnaire')->send_questionnaires( {
            site => 'fixmystreet'
        } );

        my $email = $mech->get_email;
        my $url = $mech->get_link_from_email($email, 0, 1);
        $mech->clear_emails_ok;
        $mech->get_ok($url);
        $mech->submit_form_ok( { with_fields => $test->{fields} }, "Questionnaire submitted");
        $mech->get_ok('/report/' . $problem->id);
        $problem = FixMyStreet::DB->resultset('Problem')->find_or_create( { id => $problem->id } );
        is $problem->state, $test->{report_status}, $test->{desc};
        my $questionnaire = FixMyStreet::DB->resultset('Questionnaire')->find( {
            problem_id => $problem->id
        } );

        $questionnaire->delete;
        $problem->comments->first->delete;
        $problem->delete;
        }
    };
};

for my $test (
    {
        desc => 'No commas when only resolution coded',
        resolution_code => 60,
        task_type => '',
        task_state => '',
        result => 60,
    },
    {
        desc => 'Commas in full waste details',
        resolution_code => 60,
        task_type => 20,
        task_state => 40,
        result => '60,20,40',
    },
    {
        desc => 'Commas if only task_state ',
        resolution_code => '',
        task_type => '',
        task_state => 40,
        result => ',,40',
    },
) {
    subtest 'Brent templates provide external_status_code for non-waste reports' => sub {
        FixMyStreet::override_config {
            ALLOWED_COBRANDS => 'brent',
    }, sub {
        $mech->log_in_ok($super_user->email);
        $mech->get_ok('/admin/templates/' . $brent->id . '/new');
        $mech->submit_form_ok({ with_fields => {
            title => 'We are investigating your report',
            text => 'We are now looking into your report and will update you soon.',
            resolution_code => $test->{resolution_code},
            task_type => $test->{task_type},
            task_state => $test->{task_state},
        } });
        my $template = $brent->response_templates->first;
        is($template->external_status_code, $test->{result}, $test->{desc});
        $template->delete;
        $template->update;
        $mech->log_out_ok;
        };
    };
};

subtest "Open311 attribute changes" => sub {
    my ($problem) = $mech->create_problems_for_body(1, $brent->id, 'Gully', {
        areas => "2488", category => 'Gully grid missing', cobrand => 'brent',
    });
    $problem->update_extra_field({ name => 'UnitID', value => '234' });
    $problem->update;

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'brent',
        MAPIT_URL => 'http://mapit.uk/',
        STAGING_FLAGS => { send_reports => 1 },
        COBRAND_FEATURES => {
            anonymous_account => {
                brent => 'anonymous'
            },
        },
    }, sub {
        FixMyStreet::Script::Reports::send();
        my $req = Open311->test_req_used;
        my $c = CGI::Simple->new($req->content);
        is $c->param('attribute[UnitID]'), undef, 'UnitID removed from attributes';
        like $c->param('description'), qr/ukey: 234/, 'UnitID on gully sent across in detail';
        is $c->param('attribute[title]'), $problem->title, 'Report title passed as attribute for Open311';
    };

    $problem->delete;
};

my $tilma = t::Mock::Tilma->new;
LWP::Protocol::PSGI->register($tilma->to_psgi_app, host => 'tilma.mysociety.org');

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'brent', 'tfl' ],
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    subtest "hides the TfL River Piers category" => sub {

        $brent->contacts->delete;
        $mech->create_contact_ok(body_id => $brent->id, category => 'Potholes', email => 'potholes@brent.fixmystreet.com');

        my $tfl = $mech->create_body_ok(2488, 'TfL');
        $mech->create_contact_ok(body_id => $tfl->id, category => 'River Piers', email => 'tfl@example.org');
        $mech->create_contact_ok(body_id => $tfl->id, category => 'River Piers - Cleaning', email => 'tfl@example.org');
        $mech->create_contact_ok(body_id => $tfl->id, category => 'River Piers Damage doors and glass', email => 'tfl@example.org');

        ok $mech->host('brent.fixmystreet.com'), 'set host';
        my $json = $mech->get_ok_json('/report/new/ajax?latitude=51.55904&longitude=-0.28168');
        is $json->{by_category}->{"River Piers"}, undef, "Brent doesn't have River Piers category";
        is $json->{by_category}->{"River Piers - Cleaning"}, undef, "Brent doesn't have River Piers with hyphen and extra text category";
        is $json->{by_category}->{"River Piers Damage doors and glass"}, undef, "Brent doesn't have River Piers with extra text category";
    };
};

package SOAP::Result;
sub result { return $_[0]->{result}; }
sub new { my $c = shift; bless { @_ }, $c; }

package main;

subtest 'push updating of reports' => sub {
    my $integ = Test::MockModule->new('SOAP::Lite');
    $integ->mock(call => sub {
        my ($cls, @args) = @_;
        my $method = $args[0]->name;
        if ($method eq 'GetEvent') {
            my ($key, $type, $value) = ${$args[3]->value}->value;
            my $external_id = ${$value->value}->value->value;
            my ($waste, $event_state_id, $resolution_code) = split /-/, $external_id;
            return SOAP::Result->new(result => {
                EventStateId => $event_state_id,
                EventTypeId => '943',
                LastUpdatedDate => { OffsetMinutes => 60, DateTime => '2020-06-24T14:00:00Z' },
                ResolutionCodeId => $resolution_code,
            });
        } elsif ($method eq 'GetEventType') {
            return SOAP::Result->new(result => {
                Workflow => { States => { State => [
                    { CoreState => 'New', Name => 'New', Id => 7671 },
                    { CoreState => 'Cancelled', Name => 'Rejected ', Id => 7672,
                      ResolutionCodes => { StateResolutionCode => [
                        { ResolutionCodeId => 48, Name => 'Duplicate' },
                        { ResolutionCodeId => 100, Name => 'No Access' },
                      ] } },
                    { CoreState => 'Pending', Name => 'Accepted', Id => 7673 },
                    { CoreState => 'Pending', Name => 'Allocated to Crew', Id => 7679 },
                    { CoreState => 'Closed', Name => 'Completed ', Id => 7680 },
                    { CoreState => 'Closed', Name => 'Not Completed', Id => 7681,
                      ResolutionCodes => { StateResolutionCode => [
                        { ResolutionCodeId => 67, Name => 'Nothing Found' },
                        { ResolutionCodeId => 31, Name => 'Breakdown' },
                        { ResolutionCodeId => 14, Name => 'Inclement weather conditions ' },
                      ] } },
                    { CoreState => 'Pending', Name => 'Re-Open', Id => 14683 },
                ] } },
            });
        } else {
            is $method, 'UNKNOWN';
        }
    });

    my $report;
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'brent',
        COBRAND_FEATURES => {
            echo => { brent => { url => 'https://www.example.org/' } },
            #waste => { brent => 1 }
        },
    }, sub {
        $brent->response_templates->create({
            title => 'Allocated title', text => 'This has been allocated',
            'auto_response' => 1, state => 'in progress',
        });

        ($report) = $mech->create_problems_for_body(1, $brent->id, 'Graffiti', {
            category => 'Graffiti',
        });
        my $cobrand = FixMyStreet::Cobrand::Brent->new;

        $report->update({ external_id => 'Echo-waste-7671-' });
        stdout_like {
            $cobrand->waste_fetch_events({ verbose => 1 });
        } qr/Fetching data for report/;
        $report->discard_changes;
        is $report->comments->count, 0, 'No new update';
        is $report->state, 'confirmed', 'No state change';

        $report->update({ external_id => 'Echo-waste-7679-' });
        stdout_like {
            $cobrand->waste_fetch_events({ verbose => 1 });
        } qr/Updating report to state in progress, Allocated to Crew/;
        $report->discard_changes;
        is $report->comments->count, 1, 'A new update';
        my $update = $report->comments->first;
        is $update->text, 'This has been allocated';
        is $report->state, 'in progress', 'A state change';

        $report->update({ external_id => 'Echo-waste-7681-67' });
        stdout_like {
            $cobrand->waste_fetch_events({ verbose => 1 });
        } qr/Updating report to state unable to fix, Nothing Found/;
        $report->discard_changes;
        is $report->comments->count, 2, 'A new update';
        is $report->state, 'unable to fix', 'Changed to no further action';
    };

    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'brent',
        COBRAND_FEATURES => {
            echo => { brent => {
                url => 'https://www.example.org/',
                receive_action => 'action',
                receive_username => 'un',
                receive_password => 'password',
            } },
            waste => { brent => 1 }
        },
    }, sub {
        my $in = <<EOF;
<?xml version="1.0" encoding="UTF-8"?>
<Envelope>
  <Header>
    <Action>action</Action>
    <Security><UsernameToken><Username>un</Username><Password>password</Password></UsernameToken></Security>
  </Header>
  <Body>
    <NotifyEventUpdated>
      <event>
        <Guid>waste-7681-67</Guid>
        <EventTypeId>943</EventTypeId>
        <EventStateId>7672</EventStateId>
        <ResolutionCodeId>100</ResolutionCodeId>
      </event>
    </NotifyEventUpdated>
  </Body>
</Envelope>
EOF
        my $mech2 = $mech->clone;
        $mech2->post('/waste/echo', Content_Type => 'text/xml', Content => $in);
        is $report->comments->count, 3, 'A new update';
        $report->discard_changes;
        is $report->state, 'closed', 'A state change';
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'brent' ],
    MAPIT_URL => 'http://mapit.uk/'
}, sub {
    subtest 'test geocoder_munge_results returns nicely named options' => sub {
        $mech->get_ok('/', "Get search page");
        $mech->submit_form_ok(
            { with_fields => {
                pc => 'Engineers Way'
            }
        }, "Search for Engineers Way");

        $mech->content_contains('Engineers Way, HA9 0FJ', 'Strips out extra Brent text');
    }
};

done_testing();
