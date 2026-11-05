use CGI::Simple;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use FixMyStreet::Script::CSVExport;
use File::Temp 'tempdir';
use Test::MockModule;

my $mech = FixMyStreet::TestMech->new;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $gc = Test::MockModule->new('FixMyStreet::Geocode');

$gc->mock('cache', sub {
    my $type = shift;
    return [
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
        { # near duplicate so we don't jump straight to report page with only one result
          'osm_type' => 'way',
          'type' => 'tertiary',
          'display_name' => 'Engineers Road, London Borough of Brent, London, Greater London, England, HA9 0FJ, United Kingdom',
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
        if $type eq 'osm';

    return {
        results => [
            { LPI => {
                  "UPRN" => "202204308",
                  "ADDRESS" => "STUDIO 1, 29, BUCKINGHAM ROAD, LONDON, BRENT, NW10 4RP",
                  "USRN" => "20202572",
                  "SAO_TEXT" => "STUDIO 1",
                  "PAO_START_NUMBER" => "29",
                  "STREET_DESCRIPTION" => "BUCKINGHAM ROAD",
                  "TOWN_NAME" => "LONDON",
                  "ADMINISTRATIVE_AREA" => "BRENT",
                  "POSTCODE_LOCATOR" => "NW10 4RP",
            } }
        ],
    }
        if $type eq 'osplaces';
});

use_ok 'FixMyStreet::Cobrand::Brent';

my $super_user = $mech->create_user_ok('superuser@example.com', is_superuser => 1, name => "Super User");
my $comment_user = $mech->create_user_ok('comment@example.org', email_verified => 1, name => 'Brent');
my $brent = $mech->create_body_ok(2488, 'Brent Council', {
    api_key => 'abc',
    jurisdiction => 'brent',
    endpoint => 'http://endpoint.example.org',
    send_method => 'Open311',
    comment_user => $comment_user,
    send_extended_statuses => 1,
    cobrand => 'brent'
});
my $atak_contact = $mech->create_contact_ok(body_id => $brent->id, category => 'ATAK', email => 'ATAK');

FixMyStreet::DB->resultset('BodyArea')->find_or_create({ area_id => 2505, body_id => $brent->id }); # Camden
FixMyStreet::DB->resultset('BodyArea')->find_or_create({ area_id => 2487, body_id => $brent->id }); # Harrow
FixMyStreet::DB->resultset('BodyArea')->find_or_create({ area_id => 2489, body_id => $brent->id }); # Barnet

my $camden = $mech->create_body_ok(2505, 'Camden Borough Council', {cobrand => 'camden'});
my $barnet = $mech->create_body_ok(2489, 'Barnet Borough Council');
my $harrow = $mech->create_body_ok(2487, 'Harrow Borough Council');
FixMyStreet::DB->resultset('BodyArea')->find_or_create({
    area_id => 2488,
    body_id => $barnet->id,
});
FixMyStreet::DB->resultset('BodyArea')->find_or_create({
    area_id => 2488,
    body_id => $camden->id,
});
FixMyStreet::DB->resultset('BodyArea')->find_or_create({
    area_id => 2488,
    body_id => $harrow->id,
});
my $hammersmith = $mech->create_body_ok(2502, 'Hammersmith and Fulham Borough Council');
my $kensington = $mech->create_body_ok(2503, 'Kensington and Chelsea Borough Council');
my $contact = $mech->create_contact_ok(body_id => $brent->id, category => 'Graffiti', email => 'graffiti@example.org', extra => {
    _fields => [{
        code => 'UnitID',
        description => 'Unit ID',
        automated => 'hidden_field',
    }]
});
my $gully = $mech->create_contact_ok(body_id => $brent->id, category => 'Gully grid missing',
    email => 'Symology-gully', group => ['Drains and gullies']);
my $parks_contact = $mech->create_contact_ok(body_id => $brent->id, category => 'Overgrown grass',
    email => 'ATAK-OVERGROWN_GRASS', group => 'Parks and open spaces');
my $parks_contact2 = $mech->create_contact_ok(body_id => $brent->id, category => 'Leaf clearance',
    email => 'ATAK-LEAF_CLEARANCE', group => 'Parks and open spaces');
my $parks_contact3 = $mech->create_contact_ok(body_id => $brent->id, category => 'Ponds',
    email => 'ponds@example.org', group => 'Parks and open spaces');
my $user1 = $mech->create_user_ok(
    'user1@example.org',
    email_verified => 1,
    name           => 'User 1',
    phone          => '44 07 999 999 999',
    phone_verified => 1,
);
my $role = FixMyStreet::DB->resultset("Role")->create({
    body => $brent,
    name => 'Role',
    permissions => ['moderate', 'user_edit', 'view_dashboard'],
});
my $staff_user = $mech->create_user_ok('staff@example.org', from_body => $brent, name => 'Staff User');
$staff_user->user_roles->find_or_create({ role_id => $role->id });

subtest 'role report shows staff problem when staff logged in during problem reporting process' => sub {
  my $UPLOAD_DIR = tempdir( CLEANUP => 1 );
  FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'brent',
    MAPIT_URL => 'http://mapit.uk/',
    PHOTO_STORAGE_OPTIONS => { UPLOAD_DIR => $UPLOAD_DIR },
  }, sub {
    $mech->get_ok("/report/new?longitude=-0.28168&latitude=51.55904");
    $mech->submit_form_ok( { with_fields => { category => 'Graffiti', title => 'Spraypaint on wall', detail => 'Some kind of picture', name => 'Staff User', username_register => $mech->uniquify_email('staff@example.org') } }, 'Staff user logs in whilst making report' );
    $mech->get_ok($mech->get_link_from_email($mech->get_email));
    $mech->get_ok('/dashboard?body=' . $brent->id . '&state=&role=' . $role->id . '&start_date=&end_date=&group_by=category+state&export=1');
    $mech->content_contains('"Spraypaint on wall","Some kind of picture"', 'Report has contributed_by set and so shows in roles report');
    FixMyStreet::DB->resultset('Problem')->order_by('-id')->first->delete;
    $mech->clear_emails_ok;
    $mech->log_out_ok;
  };
};

# Add location_name field to parks categories
for my $contact ($parks_contact, $parks_contact2, $parks_contact3) {
    $contact->set_extra_fields(
        { code => 'location_name', required => 0, automated => 'hidden_field' },
    );
    $contact->update;
}

$mech->create_contact_ok(body_id => $brent->id, category => 'Potholes', email => 'potholes@brent.example.org');

$contact = $mech->create_contact_ok(body => $brent, category => 'Fly-tip Small - Less than one bag', email => 'Echo-flytipping');
$contact->set_extra_fields(
    { code => 'Did_you_see_the_Flytip_take_place?_', required => 1, values => [
        { name => 'Yes', key => 1 }, { name => 'No', key => 0 }
    ] },
    { code => 'Are_you_willing_to_be_a_WItness?_', required => 1, values => [
        { name => 'Yes', key => 1 }, { name => 'No', key => 0 }
    ] },
    { code => 'Flytip_Size', required => 1, values => [
        { name => 'Single item', key => 2 }, { name => 'Small van load', key => 4 }

    ] },
    { code => 'Flytip_Type', required => 1, values => [
        { name => 'Appliance', key => 13 }, { name => 'Bagged waste', key => 3 }
    ] },
);
$contact->update;

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
    subtest "title is labelled 'location of problem' in open311 extended description" => sub {
        my ($problem) = $mech->create_problems_for_body(1, $brent->id, 'title', {
            category => 'Graffiti' ,
            areas => '2488',
            cobrand => 'brent',
        });

        FixMyStreet::Script::Reports::send();
        my $req = Open311->test_req_used;
        my $c = CGI::Simple->new($req->content);
        like $c->param('description'), qr/location of problem: title/, "title labeled correctly";
        $problem->delete;
    };

    subtest "ATAK reports go straight to investigating after being sent" => sub {
        my ($problem) = $mech->create_problems_for_body(1, $brent->id, 'title', {
            category => 'ATAK' ,
            areas => '2488',
            cobrand => 'brent',
        });

        FixMyStreet::Script::Reports::send();

        $problem = FixMyStreet::DB->resultset('Problem')->find( { id => $problem->id } );
        is $problem->state, "investigating", "ATAK problem is in investigating after being sent";
        $problem->delete;
    };
};

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

subtest 'Brent templates provide external_status_code for non-waste reports' => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => 'brent',
    }, sub {
        my ($problem) = $mech->create_problems_for_body(1, $brent->id, 'Title', {
        areas => ",2488,", category => 'Overgrown grass', send_state => 'sent' });
        $mech->log_in_ok($super_user->email);
        $mech->get_ok('/admin/report_edit/' . $problem->id);
        $mech->submit_form_ok({ with_fields => { category => 'Fly-tip Small - Less than one bag' } });
        $problem->discard_changes;
        is $problem->send_state, 'unprocessed', "Marked for resending";
        $problem->comments->delete;
        $problem->delete;
        $mech->log_out_ok;
    };
};

subtest "Open311 attribute changes" => sub {
    subtest 'OSM geocoder' => sub {
        my ($problem) = $mech->create_problems_for_body(
            1,
            $brent->id,
            'Gully',
            {   areas    => "2488",
                category => 'Gully grid missing',
                cobrand  => 'brent',
                geocode  => { display_name => 'Engineers Way, London Borough of Brent, London, Greater London, England, HA9 0FJ, United Kingdom' },
            }
        );
        $problem->update_extra_field( { name => 'UnitID', value => '234' } );
        $problem->update_extra_field( { name => 'NSGRef', value => 'BadUSRN' } );
        $problem->update;

        FixMyStreet::override_config {
            ALLOWED_COBRANDS => 'brent',
            MAPIT_URL        => 'http://mapit.uk/',
            STAGING_FLAGS    => { send_reports => 1 },
            COBRAND_FEATURES => {
                anonymous_account => { brent => 'anonymous' },
                area_code_mapping => { brent => { BadUSRN => 'GoodUSRN' } },
            },
        }, sub {
            FixMyStreet::Script::Reports::send();
            my $req = Open311->test_req_used;
            my $c   = CGI::Simple->new( $req->content );
            is $c->param('attribute[UnitID]'), undef,
                'UnitID removed from attributes';
            is $c->param('attribute[NSGRef]'), 'GoodUSRN', 'USRN updated';
            like $c->param('description'), qr/ukey: 234/,
                'UnitID on gully sent across in detail';
            my $title = $problem->title
                . '; Nearest calculated address = Engineers Way, London Borough of Brent, London, Greater London, HA9 0FJ';
            is $c->param('attribute[title]'), $title,
                'Report title and location passed as attribute for Open311';
        };

        $problem->delete;
    };

    subtest 'OSPlaces geocoder' => sub {
        my ($problem) = $mech->create_problems_for_body(
            1,
            $brent->id,
            'Gully',
            {   areas    => "2488",
                category => 'Gully grid missing',
                cobrand  => 'brent',
                geocode => {
                    LPI => {
                        "ADDRESS" =>
                            "STUDIO 1, 29, BUCKINGHAM ROAD, LONDON, BRENT, NW10 4RP",
                    },
                },
            }
        );
        $problem->update_extra_field( { name => 'UnitID', value => '234' } );
        $problem->update;

        FixMyStreet::override_config {
            ALLOWED_COBRANDS => 'brent',
            MAPIT_URL        => 'http://mapit.uk/',
            STAGING_FLAGS    => { send_reports => 1 },
            COBRAND_FEATURES => {
                anonymous_account => { brent => 'anonymous' },
                geocoder_reverse  => { brent => 'OSPlaces' },
                os_places_api_key => { brent => 'key' },
            },
        }, sub {
            # send() will overwrite report's geocode with one for OSPlaces
            FixMyStreet::Script::Reports::send();
            my $req = Open311->test_req_used;
            my $c   = CGI::Simple->new( $req->content );
            is $c->param('attribute[UnitID]'), undef,
                'UnitID removed from attributes';
            like $c->param('description'), qr/ukey: 234/,
                'UnitID on gully sent across in detail';
            my $title = $problem->title
                . '; Nearest calculated address = Studio 1, 29, Buckingham Road, London, Brent, NW10 4RP';
            is $c->param('attribute[title]'), $title,
                'Report title and location passed as attribute for Open311';
        };

        $problem->delete;
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'brent', 'tfl' ],
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    subtest "hides the TfL River Piers category" => sub {

        my $tfl = $mech->create_body_ok(2488, 'TfL');
        FixMyStreet::DB->resultset('BodyArea')->find_or_create({
            area_id => 2505, # Camden
            body_id => $tfl->id,
        });
        $mech->create_contact_ok(body_id => $tfl->id, category => 'River Piers', email => 'tfl@example.org');
        $mech->create_contact_ok(body_id => $tfl->id, category => 'River Piers - Cleaning', email => 'tfl@example.org');
        $mech->create_contact_ok(body_id => $tfl->id, category => 'River Piers Damage doors and glass', email => 'tfl@example.org');
        $mech->create_contact_ok(body_id => $tfl->id, category => 'Bus Station Cleaning - General', email => 'tfl@example.org');
        $mech->create_contact_ok(body_id => $tfl->id, category => 'Graffiti / Flyposting (Response Desk Buses to Action)', email => 'tfl@example.org');

        $mech->create_contact_ok(body_id => $tfl->id, category => 'Sweeping', email => 'tfl@example.org');
        ok $mech->host('brent.fixmystreet.com'), 'set host';
        my $json = $mech->get_ok_json('/report/new/ajax?latitude=51.55904&longitude=-0.28168');
        is $json->{by_category}->{"River Piers"}, undef, "Brent doesn't have River Piers category";
        is $json->{by_category}->{"River Piers - Cleaning"}, undef, "Brent doesn't have River Piers with hyphen and extra text category";
        is $json->{by_category}->{"River Piers Damage doors and glass"}, undef, "Brent doesn't have River Piers with extra text category";
        is $json->{by_category}->{"Bus Station Cleaning - General"}, undef, "Brent doesn't have Bus Station category beginning with 'Bus Station'";
        is $json->{by_category}->{"Graffiti / Flyposting (Response Desk Buses to Action)"}, undef, "Brent doesn't have Bus Station category including 'Response Desk Buses to Action'";

    };

    subtest "has the correct pin colours" => sub {
        my $cobrand = $brent->get_cobrand_handler;

        my ($problem) = $mech->create_problems_for_body(1, $brent->id, 'Title', {
            areas => '2488', category => 'Graffiti', cobrand => 'brent', user => $user1
        });

        $problem->state('confirmed');
        is $cobrand->pin_colour($problem, 'around'), 'yellow-cone', 'confirmed problem has correct pin colour';

        $problem->state('closed');
        is $cobrand->pin_colour($problem, 'around'), 'grey-cross', 'closed problem has correct pin colour';

        $problem->state('fixed');
        is $cobrand->pin_colour($problem, 'around'), 'green-tick', 'fixed problem has correct pin colour';

        $problem->state('in_progress');
        is $cobrand->pin_colour($problem, 'around'), 'orange-work', 'in_progress problem has correct pin colour';
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'brent', 'tfl', 'camden', 'fixmystreet' ],
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    $mech->create_contact_ok(body_id => $camden->id, category => 'Dead animal', email => 'animal@camden.org');
    $mech->create_contact_ok(body_id => $camden->id, category => 'Fly-tipping', email => 'flytipping@camden.org');
    $mech->create_contact_ok(body_id => $barnet->id, category => 'Abandoned vehicles', email => 'vehicles@barnet.org');
    $mech->create_contact_ok(body_id => $barnet->id, category => 'Parking', email => 'parking@barnet.org');

        my $brent_mock = Test::MockModule->new('FixMyStreet::Cobrand::Brent');
        my $camden_mock = Test::MockModule->new('FixMyStreet::Cobrand::Camden');
            foreach my $host (qw/brent fixmystreet/) {
                subtest "categories on $host cobrand in Brent on Camden cobrand layer" => sub {
                    $mech->host("$host.fixmystreet.com");
                    $brent_mock->mock('_fetch_features', sub { [{ 'ms:BrentDiffs' => { 'ms:name' => 'Camden' } } ]});
                    $camden_mock->mock('_fetch_features', sub { [ { 'ms:AgreementBoundaries' => { 'ms:RESPBOROUG' => 'LB Camden' } } ] });
                    $mech->get_ok("/report/new/ajax?longitude=-0.28168&latitude=51.55904");
                    is $mech->content_lacks("Potholes"), 1, 'Brent category not present';
                    is $mech->content_lacks("Gully grid missing"), 1, 'Brent Symology category not present';
                    is $mech->content_contains("Sweeping"), 1, 'TfL category present';
                    is $mech->content_contains("Fly-tipping"), 1, 'Camden category present';
                    is $mech->content_contains("Dead animal"), 1, 'Camden non-street category present';
                    is $mech->content_lacks("Abandoned vehicles"), 1, 'Barnet non-street category not present';
                    is $mech->content_lacks("Parking"), 1, 'Barnet street category not present';
                }
            };

            foreach my $host (qw/brent fixmystreet/) {
                subtest "categories on $host cobrand in Brent not on cobrand layer" => sub {
                    $mech->host("$host.fixmystreet.com");
                    $brent_mock->mock('_fetch_features', sub {[]});
                    $mech->get_ok("/report/new/ajax?longitude=-0.28168&latitude=51.55904");
                    is $mech->content_contains("Potholes"), 1, 'Brent category present';
                    is $mech->content_contains("Gully grid missing"), 1, 'Brent Symology category present';
                    is $mech->content_contains("Sweeping"), 1, 'TfL category present';
                    is $mech->content_lacks("Fly-tipping"), 1, 'Camden category not present';
                    is $mech->content_lacks("Dead animal"), 1, 'Camden non-street category not present';
                    is $mech->content_lacks("Abandoned vehicles"), 1, 'Barnet non-street category not present';
                    is $mech->content_lacks("Parking"), 1, 'Barnet street category not present';
                };
            };

            foreach my $host (qw/camden fixmystreet/) {
                subtest "categories on $host in Camden not on cobrand layer" => sub {
                    $mech->host("$host.fixmystreet.com");
                    $camden_mock->mock('_fetch_features', sub { [] });
                    $mech->get_ok("/report/new/ajax?longitude=-0.124514&latitude=51.529432");
                    is $mech->content_lacks("Potholes"), 1, 'Brent category not present';
                    is $mech->content_lacks("Gully grid missing"), 1, 'Brent Symology category not present';
                    is $mech->content_contains("Sweeping"), 1, 'TfL category present';
                    is $mech->content_contains("Fly-tipping"), 1, 'Camden category present';
                    is $mech->content_contains("Dead animal"), 1, 'Camden non-street category present';
                    is $mech->content_lacks("Abandoned vehicles"), 1, 'Barnet non-street category not present';
                    is $mech->content_lacks("Parking"), 1, 'Barnet street category not present';
                };
            }

            foreach my $host (qw/fixmystreet brent camden/) {
                subtest "categories on $host cobrand in Camden on Brent cobrand layer" => sub {
                    $mech->host("$host.fixmystreet.com");
                    $brent_mock->mock('_fetch_features',
                        sub { [ { 'ms:BrentDiffs' => { 'ms:name' => 'Brent' } } ] });
                    $camden_mock->mock('_fetch_features',
                        sub { [ { 'ms:AgreementBoundaries' => { 'ms:RESPBOROUG' => 'LB Brent' } } ] });
                    $mech->get_ok("/report/new/ajax?longitude=-0.124514&latitude=51.529432");
                    is $mech->content_contains("Potholes"), 1, 'Brent category present';
                    is $mech->content_contains("Gully grid missing"), 1, 'Brent Symology category present';
                    is $mech->content_contains("Sweeping"), 1, 'TfL category present';
                    is $mech->content_lacks("Fly-tipping"), 1, 'Camden street category not present';
                    is $mech->content_lacks("Dead animal"), 1, 'Camden non-street category not present';
                }
            };

            foreach my $host (qw/fixmystreet brent/) {
                subtest "categories on $host cobrand in Brent on Barnet cobrand layer" => sub {
                    $mech->host("$host.fixmystreet.com");
                    $brent_mock->mock('_fetch_features', sub {[ { 'ms:BrentDiffs' => { 'ms:name' => 'Barnet' } } ]});
                    $mech->get_ok("/report/new/ajax?longitude=-0.28168&latitude=51.55904");
                    is $mech->content_lacks("Abandoned vehicles"), 1, 'Barnet non-street category not present';
                    is $mech->content_contains("Parking"), 1, 'Barnet street category present';
                    is $mech->content_lacks("Gully grid missing"), 1, 'Brent Symology category not present';
                    is $mech->content_contains("Potholes"), 1, 'Brent category present';
                    is $mech->content_contains("Sweeping"), 1, 'TfL category present';
                    is $mech->content_lacks("Fly-tipping"), 1, 'Camden category not present';
                    is $mech->content_lacks("Dead animal"), 1, 'Camden non-street category not present';
                }
            };

            subtest "can not access Camden from Brent off asset layer" => sub {
                $mech->host("brent.fixmystreet.com");
                $brent_mock->mock('_fetch_features',
                    sub { [] });
                $mech->get_ok("/report/new?longitude=-0.124514&latitude=51.529432");
                is $mech->content_contains('That location is not covered by Brent Council'), 1, 'Can not make report in Camden off asset';
            };

            subtest "can access Camden from Brent on asset layer" => sub {
                $mech->host("brent.fixmystreet.com");
                $brent_mock->mock('_fetch_features',
                    sub { [{ 'ms:BrentDiffs' => { 'ms:name' => 'Brent' } }] });
                $mech->get_ok("/report/new?longitude=-0.124514&latitude=51.529432");
                is $mech->content_lacks('That location is not covered by Brent Council'), 1, 'Can not make report in Camden off asset';
            };

            for my $test (
                {
                    council => 'Brent',
                    location => '/report/new?longitude=-0.28168&latitude=51.55904',
                    asset => [ ],
                },
                {
                    council => 'Barnet',
                    location => '/report/new?longitude=-0.207702&latitude=51.558568',
                    asset => [ ],
                },

            ) {
                subtest "can not access $test->{council} from Camden cobrand" => sub {
                    $mech->host("camden.fixmystreet.com");
                    $camden_mock->mock('_fetch_features', sub { $test->{asset} });
                    $mech->get_ok($test->{location});
                    is $mech->content_contains('That location is not covered by Camden Council'), 1, "Can not make report in $test->{council} from Camden";
                };
            };

    undef $brent_mock;
    undef $camden_mock;

    subtest "Brent categories not shown to admin in Camden for existing report" => sub {
        $mech->host("camden.fixmystreet.com");
        my $camden_staff = $mech->create_user_ok('staff@camden.example.org', from_body => $camden, name => 'Staff User');
        $camden_staff->user_body_permissions->create({ body => $camden, permission_type => 'report_edit' });

        my ($problem) = $mech->create_problems_for_body(1, $camden->id, 'Title', {
            areas => ',11821,163653,163969,164863,164997,165466,2247,2505,34046,65576,67036,',
            category => 'Dead animal', cobrand => 'camden',
        });

        $mech->log_in_ok($camden_staff->email);
        $mech->get_ok("/admin/report_edit/" . $problem->id);
        $mech->content_contains('Dead animal'); # Camden
        $mech->content_contains('Sweeping'); # TfL
        $mech->content_lacks('Leaf clearance'); # Brent
        $mech->content_lacks('Potholes'); # Brent
        $problem->delete;
    };

    subtest "All reports page for Brent works appropriately" => sub {
        $mech->host("brent.fixmystreet.com");
        $mech->get_ok("/reports");
        $mech->content_contains('data-area="2488"');
        $mech->content_contains('Alperton');
        $mech->content_lacks('Belsize');
    };

    subtest "All reports page for Camden works appropriately" => sub {
        $mech->host("camden.fixmystreet.com");
        $mech->get_ok("/reports");
        $mech->content_contains('data-area="2505"');
        $mech->content_contains('Belsize');
        $mech->content_lacks('Alperton');
        $mech->get_ok("/reports/Camden/Belsize");
        is $mech->uri->path, '/reports/Camden/Belsize';
    };

    subtest "All reports on .com works appropriately" => sub {
        $mech->host("fixmystreet.com");
        $mech->get_ok("/reports/Brent");
        $mech->content_contains('data-area="2488"');
        $mech->content_contains('Alperton');
        $mech->content_lacks('Belsize');
        $mech->get_ok("/reports/Camden");
        $mech->content_contains('data-area="2505"');
        $mech->content_contains('Belsize');
        $mech->content_lacks('Alperton');
        $mech->get_ok("/reports/Harrow");
        $mech->content_contains('data-area="2487"');
        $mech->content_contains('Belmont');
        $mech->content_lacks('Alperton');
    };

    $mech->host("brent.fixmystreet.com");
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'brent', 'tfl', 'fixmystreet' ],
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    for my $host (
                  {
                   host => 'fixmystreet',
                   outside_text => 'We do not yet have details for the council that covers this location',
                   end_text => 'Thank you for reporting this issue'
                  },
                  {
                   host => 'brent',
                   outside_text => 'That location is not covered by Brent Council',
                   end_text => 'Your issue is on its way to the council'
                  }) {
        for my $test (
                      {
                       name => 'Hammersmith',
                       lon => '-0.228924',
                       lat => '51.530133',
                       title => 'Graffiti issue in Hammersmith from Brent',
                      },
                      {
                       name => 'Kensington',
                       lon => '-0.228293',
                       lat => '51.530115',
                       title => 'Graffiti issue in Kensington from Brent',
                      }
         ) {
            subtest "report on H&F Council and K&C Council only when on light asset" => sub {
                $mech->host($host->{host} . ".fixmystreet.com");
                $mech->get_ok('/report/new?longitude=' . $test->{lon} . '&latitude=' . $test->{lat});
                $mech->content_contains($host->{outside_text});
                $mech->log_in_ok($comment_user->email);
                $mech->get_ok("/report/new?longitude=-0.28168&latitude=51.55904&category=Graffiti", "Start report in Brent");
                $mech->submit_form_ok(
                                      { with_fields => {
                                                     name => 'Test User',
                                                     title => $test->{title},
                                                     detail => 'Graffiti issue',
                                                     longitude => $test->{lon},
                                                     latitude => $test->{lat},
                                                     UnitID => '12345',
                                                       }}, 'Location in ' . $test->{name} . ' ok as clicked from Brent location onto Brent asset');
                $mech->content_contains($host->{end_text});
                my $problem = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
                is $problem->title, $test->{title}, 'Report has been made';
                is $problem->body, 'Brent Council', 'Problem on correct body';
                $problem->delete;
            };
        };
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

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'brent',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        geocoder_reverse => { brent => 'OSPlaces' },
        os_places_api_key => { brent => 'key' },
    },
}, sub {
    subtest 'test reverse geocoding' => sub {
        my ($problem) = $mech->create_problems_for_body(1, $brent->id, 'Title', {});
        my $cobrand = FixMyStreet::Cobrand::Brent->new;
        my $closest = $cobrand->find_closest($problem);
        is $closest->summary, 'Studio 1, 29, Buckingham Road, London, Brent, NW10 4RP';
    }
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'brent', 'tfl', 'fixmystreet' ],
    MAPIT_URL => 'http://mapit.uk/',
    STAGING_FLAGS => { send_reports => 1, skip_checks => 0 },
    COBRAND_FEATURES => {
        anonymous_account => { brent => 'anonymous' },
        category_groups => { brent => 1 },
    }
}, sub {
    $mech->log_in_ok($user1->email); # Simplify report submission params by logging in
    my $cobrand = Test::MockModule->new('FixMyStreet::Cobrand::Brent');

    subtest 'Prevents reports being made outside maintained areas' => sub {
        # Simulate no locations found
        $cobrand->mock('_get', sub { "<wfs:FeatureCollection></wfs:FeatureCollection>" });

        $mech->get_ok('/report/new?latitude=51.55904&longitude=-0.28168');
        $mech->submit_form_ok({
            with_fields => {
                title => "Test Report",
                detail => 'Test report details.',
                category => 'G|Parks and open spaces',
                'category.Parksandopenspaces' => 'Overgrown grass',
            }
        }, "submit details");
        $mech->content_contains('Please select a location in a Brent maintained area');
    };

    subtest 'Allows reports to be made in maintained areas' => sub {
        # Now simulate a location being found
        $cobrand->mock('_get', sub {
            '<wfs:FeatureCollection>
  <gml:featureMember>
    <ms:Parks_and_Open_Spaces gml:id="Parks_and_Open_Spaces.King Edward VII Park, Wembley">
      <ms:site_name>King Edward VII Park, Wembley</ms:site_name>
    </ms:Parks_and_Open_Spaces>
  </gml:featureMember>
</wfs:FeatureCollection>'
        });

        $mech->get_ok('/report/new?latitude=51.55904&longitude=-0.28168');
        $mech->submit_form_ok({
            with_fields => {
                title => "Test Report",
                detail => 'Test report details.',
                category => 'G|Parks and open spaces',
                'category.Parksandopenspaces' => 'Overgrown grass',
            }
        }, "submit details");
        $mech->content_contains('Your issue is on its way to the council') or diag $mech->content;

        FixMyStreet::Script::Reports::send();

        # Get the most recent report
        my $report = FixMyStreet::DB->resultset('Problem')->order_by('-id')->first;
        is $report->get_extra_field_value('location_name'), 'King Edward VII Park, Wembley', 'Location name is set';
    };

    subtest 'Fly-tipping category selection' => sub {
        $mech->get_ok('/report/new?latitude=51.564493&longitude=-0.277156');
        $mech->submit_form_ok({
            with_fields => {
                title => "Test Report",
                detail => 'Test report details.',
                category => 'Fly-tip Small - Less than one bag',
            }
        }, "submit details");
        my $report = FixMyStreet::DB->resultset('Problem')->order_by('-id')->first;
        is $report->category, 'Fly-tip Small - Less than one bag (Parks)';
        is $report->get_extra_metadata('group'), 'Parks and open spaces';

        $mech->get_ok('/report/new?latitude=51.563623&longitude=-0.274082');
        $mech->submit_form_ok({
            with_fields => {
                title => "Test Report",
                detail => 'Test report details.',
                category => 'Fly-tip Small - Less than one bag',
            }
        }, "submit details");
        $report = FixMyStreet::DB->resultset('Problem')->order_by('-id')->first;
        is $report->category, 'Fly-tip Small - Less than one bag (Estates)';
        is $report->get_extra_metadata('group'), 'Council Estate Grounds';

        $mech->get_ok('/report/new?latitude=51.563683&longitude=-0.276120');
        $mech->submit_form_ok({
            with_fields => {
                title => "Test Report",
                detail => 'Test report details.',
                category => 'Fly-tip Small - Less than one bag',
            }
        }, "submit details");
        $report = FixMyStreet::DB->resultset('Problem')->order_by('-id')->first;
        is $report->category, 'Fly-tip Small - Less than one bag';
        is $report->get_extra_metadata('group'), 'Fly-tipping';
    };

    subtest 'Fly-tipping category selection on .com' => sub {
        $mech->host('fixmystreet.com');
        $mech->get_ok('/report/new?latitude=51.564493&longitude=-0.277156');
        $mech->submit_form_ok({
            with_fields => {
                title => "Test Report",
                detail => 'Test report details.',
                category => 'Fly-tip Small - Less than one bag',
            }
        }, "submit details");
        my $report = FixMyStreet::DB->resultset('Problem')->order_by('-id')->first;
        is $report->category, 'Fly-tip Small - Less than one bag (Parks)';
        $mech->host('brent.fixmystreet.com');
    };

    subtest "Doesn't overwrite location_name if already set" => sub {
        $mech->get_ok('/report/new?latitude=51.55904&longitude=-0.28168');
        $mech->submit_form_ok({
            with_fields => {
                title => "Test Report",
                detail => 'Test report details.',
                category => 'G|Parks and open spaces',
                'category.Parksandopenspaces' => 'Overgrown grass',
            }
        }, "submit details");
        $mech->content_contains('Your issue is on its way to the council') or diag $mech->content;


        # Get the most recent report and set the location_name
        my $report = FixMyStreet::DB->resultset('Problem')->order_by('-id')->first;
        $report->update_extra_field( { name => 'location_name', value => 'Test location name' } );
        $report->update;

        FixMyStreet::Script::Reports::send();

        $report->discard_changes;
        is $report->get_extra_field_value('location_name'), 'Test location name', 'Location name is set';
    };

    subtest "Sets location_name on non-ATAK reports in ATAK groups" => sub {
        $mech->get_ok('/report/new?latitude=51.55904&longitude=-0.28168');
        $mech->submit_form_ok({
            with_fields => {
                title => "Test Report",
                detail => 'Test report details.',
                category => 'G|Parks and open spaces',
                'category.Parksandopenspaces' => 'Ponds',
            }
        }, "submit details");
        $mech->content_contains('Your issue is on its way to the council') or diag $mech->content;

        FixMyStreet::Script::Reports::send();

        # Get the most recent report
        my $report = FixMyStreet::DB->resultset('Problem')->order_by('-id')->first;
        is $report->get_extra_field_value('location_name'), 'King Edward VII Park, Wembley', 'Location name is set';
    };
};

subtest 'Dashboard CSV extra columns' => sub {
  my $UPLOAD_DIR = tempdir( CLEANUP => 1 );
  FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'brent',
    MAPIT_URL => 'http://mapit.uk/',
    PHOTO_STORAGE_OPTIONS => { UPLOAD_DIR => $UPLOAD_DIR },
  }, sub {
    my ($flexible_problem) = $mech->create_problems_for_body(1, $brent->id, 'Flexible problem', {
        areas => "2488", category => 'Request new container', cobrand => 'brent', user => $user1, state => 'confirmed'});
    $mech->log_in_ok( $staff_user->email );
    $mech->get_ok('/dashboard?export=1');
    ok $mech->content_contains('"Created By",Email,USRN,UPRN,"External ID","Does the report have an image?","Extra details","Did you see the fly-tipping take place","If \'Yes\', are you willing to provide a statement?","How much waste is there","Type of waste","Container Request Action","Container Request Container Type","Container Request Reason","Email Renewal Reminders Opt-In","Service ID","Staff Role","Small Item 1","Small Item 2"', "New columns added");
    ok $mech->content_like(qr/Flexible problem.*?"Test User",pkg-tcobrandbrentt/, "User and email added");
    ok $mech->content_like(qr/Flexible problem.*?,,,,Y,,,,,,,,/, "All fields empty but photo exists");
    $flexible_problem->set_extra_fields(
        {name => 'Container_Request_Action', value => 1},
        {name => 'Container_Request_Container_Type', value => 1},
        {name => 'Container_Request_Reason', value => 1},
        {name => 'service_id', value => 1},
        {name => 'usrn', value => 1234},
    );
    $flexible_problem->uprn(4321);
    $flexible_problem->external_id('121');
    $flexible_problem->update;
    $mech->get_ok('/dashboard?export=1');
    ok $mech->content_like(qr/Flexible problem.*?,1234,4321,121,Y,,,,,,Deliver,"Blue rubbish sack",Missing,,1/, "Bin request values added");
    $flexible_problem->category('Fly-tipping');
    $flexible_problem->set_extra_fields(
        {name => 'Did_you_see_the_Flytip_take_place?_', value => 1},
        {name => 'Are_you_willing_to_be_a_WItness?_', value => 0},
        {name => 'Flytip_Size', value => 4},
        {name => 'Flytip_Type', value => 13},
    );
    $flexible_problem->update;
    $mech->get_ok('/dashboard?export=1');
    ok $mech->content_like(qr/Flexible problem.*?,121,Y,,Yes,No,"Small van load",Appliance,/, "Flytip request values added");
    $flexible_problem->set_extra_fields(
        {name => 'location_name', value => 'Test Park'},
    );
    $flexible_problem->update;
    $mech->get_ok('/dashboard?export=1');
    ok $mech->content_like(qr/Flexible problem.*?,,,"Test Park","Test User",.*?,,4321,121,Y,,,,,,,,,,,/, "Location name added") or diag $mech->content;
    $flexible_problem->set_extra_metadata('item_1' => 'Sofa', 'item_2' => 'Wardrobe');
    $flexible_problem->update;
    $mech->get_ok('/dashboard?export=1');
    ok $mech->content_like(qr/Flexible problem.*?,,,"Test Park","Test User",.*?,,4321,121,Y,,,,,,,,,,,,Sofa,Wardrobe,,,,,,,/, "Bulky items added") or diag $mech->content;
    $flexible_problem->set_extra_metadata('contributed_by' => $staff_user->id);
    $flexible_problem->update;
    $mech->get_ok('/dashboard?export=1');
    ok $mech->content_like(qr/Flexible problem.*?,,,"Test Park","Test User",.*?,,4321,121,Y,,,,,,,,,,,Role,Sofa,Wardrobe,,,,,,,/, "Role added") or diag $mech->content;
  }
};

subtest 'Dashboard CSV pre-generation' => sub {
  my $UPLOAD_DIR = tempdir( CLEANUP => 1 );
  FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'brent',
    MAPIT_URL => 'http://mapit.uk/',
    PHOTO_STORAGE_OPTIONS => { UPLOAD_DIR => $UPLOAD_DIR },
  }, sub {
    my @problems = $mech->create_problems_for_body(3, $brent->id, 'Pregen problem', {
        areas => "2488", category => 'Request new container', cobrand => 'brent', user => $user1, state => 'confirmed'});
    $problems[0]->set_extra_fields(
        {name => 'Container_Request_Action', value => '2::1'},
        {name => 'Container_Request_Container_Type', value => '11::11'},
        {name => 'Container_Request_Reason', value => '4::4'},
        {name => 'service_id', value => 1},
        {name => 'usrn', value => 1234},
    );
    $problems[0]->uprn(4321);
    $problems[0]->external_id('121');
    $problems[0]->update;
    $problems[1]->category('Fly-tipping');
    $problems[1]->state('investigating');
    $problems[1]->set_extra_fields(
        {name => 'Did_you_see_the_Flytip_take_place?_', value => 1},
        {name => 'Are_you_willing_to_be_a_WItness?_', value => 0},
        {name => 'Flytip_Size', value => 4},
        {name => 'Flytip_Type', value => 13},
    );
    $problems[1]->update;
    $problems[2]->set_extra_fields( {name => 'location_name', value => 'Test Park'},);
    $problems[2]->set_extra_metadata('item_1' => 'Sofa', 'item_2' => 'Wardrobe');
    $problems[2]->update;
    FixMyStreet::Script::CSVExport::process(dbh => FixMyStreet::DB->schema->storage->dbh);
    $mech->get_ok('/dashboard?export=1');
    $mech->content_contains('"Created By",Email,USRN,UPRN,"External ID","Does the report have an image?","Extra details","Did you see the fly-tipping take place","If \'Yes\', are you willing to provide a statement?","How much waste is there","Type of waste","Container Request Action","Container Request Container Type","Container Request Reason","Email Renewal Reminders Opt-In","Service ID","Staff Role","Small Item 1","Small Item 2"', "New columns added");
    $mech->content_like(qr/Pregen problem Test 3.*?"Test User",pkg-tcobrandbrentt/, "User and email added");
    $mech->content_like(qr/Pregen problem Test 3.*?,1234,4321,121,Y,,,,,,Collect\+Deliver,"Food waste caddy",Damaged,,1/, "Bin request values added");
    $mech->content_like(qr/Pregen problem Test 2.*?,,Y,,Yes,No,"Small van load",Appliance,/, "Flytip request values added");
    $mech->content_like(qr/Pregen problem Test 1.*?,,,"Test Park","Test User",.*?,,,,Y,,,,,,,,,,,,Sofa,Wardrobe,,,,,,,/, "Bulky items added");
    $problems[2]->set_extra_metadata('contributed_by' => $staff_user->id);
    $problems[2]->update;
    FixMyStreet::Script::CSVExport::process(dbh => FixMyStreet::DB->schema->storage->dbh);
    $mech->get_ok('/dashboard?export=1');
    $mech->content_like(qr/Pregen problem Test 1.*?,,,"Test Park","Test User",.*?,,,,Y,,,,,,,,,,,Role,Sofa,Wardrobe,,,,,,,/, "Role added");
    $mech->get_ok('/dashboard?export=1&state=investigating');
    $mech->content_contains('Pregen problem Test 2');
    $mech->get_ok('/dashboard?export=1&state=fixed');
    $mech->content_lacks('Pregen problem Test 2');
  }
};

sub get_report_from_redirect {
    my $url = shift;

    my ($report_id, $token) = ( $url =~ m#/(\d+)/([^/]+)$# );
    my $new_report = FixMyStreet::DB->resultset('Problem')->find( {
            id => $report_id,
    });

    return undef unless $new_report->get_extra_metadata('redirect_id') eq $token;
    return ($token, $new_report, $report_id);
}

sub shared_echo_mocks {
    my $e = Test::MockModule->new('Integrations::Echo');
    $e->mock('GetPointAddress', sub {
        return {
            Id => 12345,
            SharedRef => { Value => { anyType => '1000000002' } },
            PointType => 'PointAddress',
            PointAddressType => { Name => 'House' },
            Coordinates => { GeoPoint => { Latitude => 51.55904, Longitude => -0.28168 } },
            Description => '2 Example Street, Brent, NW2 1AA',
        };
    });
    $e->mock('GetEventsForObject', sub { [] });
    $e->mock('GetTasks', sub { [] });
    return $e;
}

done_testing();
