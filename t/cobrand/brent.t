use CGI::Simple;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use FixMyStreet::Script::CSVExport;
use File::Temp 'tempdir';
use t::Mock::Tilma;
use Test::MockTime qw(:all);
use Test::MockModule;
use Test::Output;

my $mech = FixMyStreet::TestMech->new;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $tilma = t::Mock::Tilma->new;
LWP::Protocol::PSGI->register($tilma->to_psgi_app, host => 'tilma.staging.mysociety.org');
LWP::Protocol::PSGI->register($tilma->to_psgi_app, host => 'tilma.mysociety.org');

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
# Mock fetching bank holidays
my $uk = Test::MockModule->new('FixMyStreet::Cobrand::UK');
$uk->mock('_fetch_url', sub { '{}' });

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

my $contact = $mech->create_contact_ok(body_id => $brent->id, category => 'Graffiti', email => 'graffiti@example.org');
my $gully = $mech->create_contact_ok(body_id => $brent->id, category => 'Gully grid missing',
    email => 'Symology-gully', group => ['Drains and gullies']);
my $parks_contact = $mech->create_contact_ok(body_id => $brent->id, category => 'Overgrown grass',
    email => 'ATAK-OVERGROWN_GRASS', group => 'Parks and open spaces');
my $parks_contact2 = $mech->create_contact_ok(body_id => $brent->id, category => 'Leaf clearance',
    email => 'ATAK-LEAF_CLEARANCE', group => 'Parks and open spaces');
my $parks_contact3 = $mech->create_contact_ok(body_id => $brent->id, category => 'Ponds',
    email => 'ponds@example.org', group => 'Parks and open spaces');
my $user1 = $mech->create_user_ok('user1@example.org', email_verified => 1, name => 'User 1');
my $role = FixMyStreet::DB->resultset("Role")->create({
    body => $brent,
    name => 'Role',
    permissions => ['moderate', 'user_edit'],
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

sub create_contact {
    my ($params, @extra) = @_;
    my $contact = $mech->create_contact_ok(body => $brent, %$params, extra => { type => 'waste' });
    $contact->set_extra_fields(
        { code => 'uprn', required => 1, automated => 'hidden_field' },
        { code => 'property_id', required => 1, automated => 'hidden_field' },
        { code => 'service_id', required => 0, automated => 'hidden_field' },
        @extra,
    );
    $contact->update;
}

$contact = $mech->create_contact_ok(body => $brent, category => 'Fly-tip Small - Less than one bag', email => 'flytipping@brent.example.org');
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

create_contact({ category => 'Report missed collection', email => 'missed' });
create_contact({ category => 'Request new container', email => 'request@example.org' },
    { code => 'Container_Request_Quantity', required => 1, automated => 'hidden_field' },
    { code => 'Container_Request_Container_Type', required => 1, automated => 'hidden_field' },
    { code => 'Container_Request_Action', required => 0, automated => 'hidden_field' },
    { code => 'Container_Request_Notes', required => 0, automated => 'hidden_field' },
    { code => 'Container_Request_Reason', required => 0, automated => 'hidden_field' },
    { code => 'service_id', required => 0, automated => 'hidden_field' },
    { code => 'PaymentCode', required => 0, automated => 'hidden_field' },
    { code => 'payment_method', required => 1, automated => 'hidden_field' },
    { code => 'payment', required => 1, automated => 'hidden_field' },
    { code => 'request_referral', required => 0, automated => 'hidden_field' },
    { code => 'request_how_long_lived', required => 0, automated => 'hidden_field' },
    { code => 'request_ordered_previously', required => 0, automated => 'hidden_field' },
    { code => 'request_contamination_reports', required => 0, automated => 'hidden_field' },
);
create_contact({ category => 'Assisted collection add', email => 'assisted' },
    { code => 'Notes', description => 'Additional notes', required => 0, datatype => 'text' },
    { code => 'staff_form', automated => 'hidden_field' },
);

create_contact({ category => 'Staff general enquiry', email => 'general@brent.gov.uk' },
    { code => 'Notes', description => 'Please put your question in here for a general enquiry', required => 1, datatype => 'text' },
    { code => 'staff_form', automated => 'hidden_field' },
    { code => 'service_id', required => 1, automated => 'hidden_field' },
);

create_contact({ category => 'Additional collection', email => 'general@brent.gov.uk' },
    { code => 'Notes', description => 'Please add your notes here', required => 1, datatype => 'text' },
    { code => 'staff_form', automated => 'hidden_field' },
    { code => 'service_id', required => 1, automated => 'hidden_field' },
);

subtest "title is labelled 'location of problem' in open311 extended description" => sub {
    my ($problem) = $mech->create_problems_for_body(1, $brent->id, 'title', {
        category => 'Graffiti' ,
        areas => '2488',
        cobrand => 'brent',
    });

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
        like $c->param('description'), qr/location of problem: title/, "title labeled correctly";
    };

    $problem->delete;
};

subtest "ATAK reports go straight to investigating after being sent" => sub {
    my ($problem) = $mech->create_problems_for_body(1, $brent->id, 'title', {
        category => 'ATAK' ,
        areas => '2488',
        cobrand => 'brent',
    });

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
    };

    $problem = FixMyStreet::DB->resultset('Problem')->find( { id => $problem->id } );
    is $problem->state, "investigating", "ATAK problem is in investigating after being sent";
    $problem->delete;
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
            my ($waste, $event_state_id, $resolution_code, $event_type) = split /-/, $external_id;
            $event_type ||= '943';
            return SOAP::Result->new(result => {
                EventStateId => $event_state_id,
                EventTypeId => $event_type,
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

    my ($report, $alert);
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

        my $report2;
        ($report, $report2) = $mech->create_problems_for_body(2, $brent->id, 'Graffiti', {
            category => 'Graffiti',
        });
        # Set last update to before the time of the first update we've mocked.
        $report->update({ lastupdate => DateTime->new(year => 2020, month => 06, day => 23, hour => 15) });
        my $report_id = $report->id;
        my $cobrand = FixMyStreet::Cobrand::Brent->new;

        $alert = FixMyStreet::DB->resultset('Alert')->create({
            alert_type => 'new_updates',
            parameter  => $report->id,
            confirmed  => 1,
            user_id    => $report->user->id,
        });

        $report2->update({ external_id => 'Symology-123' });
        $report->update({ external_id => 'Echo-waste-7671-' });
        stdout_is {
            $cobrand->waste_fetch_events({ verbose => 1 });
        } "Fetching data for report $report_id\n";
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

        $update = $report->comments->order_by('-id')->first;
        my $sent = FixMyStreet::DB->resultset("AlertSent")->search({ alert_id => $alert->id, parameter => $update->id })->first;
        is $sent, undef;

        $report->update({ external_id => 'Echo-waste-7680--1159', state => 'confirmed' });
        stdout_like {
            $cobrand->waste_fetch_events({ verbose => 1 });
        } qr/Updating report to state fixed - council, Completed/;
        $report->discard_changes;
        is $report->comments->count, 3, 'A new update';
        is $report->state, 'fixed - council', 'Changed to fixed';
        $report->update({ external_id => 'Echo-waste-7681-67' });

        $update = $report->comments->order_by('-id')->first;
        $sent = FixMyStreet::DB->resultset("AlertSent")->search({ alert_id => $alert->id, parameter => $update->id })->first;
        isnt $sent, undef;
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
        my $in = $mech->echo_notify_xml('waste-7681-67', 943, 7672, 100);
        my $mech2 = $mech->clone;
        $mech2->post('/waste/echo', Content_Type => 'text/xml', Content => $in);
        is $report->comments->count, 4, 'A new update';
        $report->discard_changes;
        is $report->state, 'closed', 'A state change';

        my $update = $report->comments->order_by('-id')->first;
        my $sent = FixMyStreet::DB->resultset("AlertSent")->search({ alert_id => $alert->id, parameter => $update->id })->first;
        is $sent, undef;

        $report->update({ state => 'confirmed' });
        $in =~ s/943/1159/;
        $in =~ s/7672/7680/;
        $mech2->post('/waste/echo', Content_Type => 'text/xml', Content => $in);
        is $report->comments->count, 5, 'A new update';
        $report->discard_changes;
        is $report->state, 'fixed - council', 'A state change';

        $update = $report->comments->order_by('-id')->first;
        $sent = FixMyStreet::DB->resultset("AlertSent")->search({ alert_id => $alert->id, parameter => $update->id })->first;
        isnt $sent, undef;

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

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'brent',
    MAPIT_URL => 'http://mapit.uk/',
    STAGING_FLAGS => { send_reports => 1 },
    COBRAND_FEATURES => {
        echo => { brent => { sample_data => 1 } },
        waste => { brent => 1 },
        anonymous_account => { brent => 'anonymous' },
        waste_calendar_links => { brent => {
            'wednesday-B2' => 'https://example.org/media/16420712/wednesdayweek2.pdf'
        } },
        ggw_calendar_links => { brent => {
            'monday-2' => [ {
                href => 'https://example.org/media/16420712/mondayweek2',
                text => 'Download PDF garden waste calendar',
            } ]
        } },
        payment_gateway => { brent => {
            cc_url => 'http://example.com',
            ggw_cost => 6000,
            request_cost_blue_bin => 3000,
            # request_cost_food_caddy => 500,
            cc_url => 'http://example.org/cc_submit',
            hmac => '1234',
            hmac_id => '1234',
            scpID => '1234',
        } },
        open311_email => { brent => {
            'Request new container' => 'referral@example.org',
        } },
    },
}, sub {
    my $echo = shared_echo_mocks();
    $echo->mock('GetServiceUnitsForObject' => sub {
    return [
        {
            Id => 1001,
            ServiceId => 265,
            ServiceName => 'Domestic Dry Recycling Collection',
            ServiceTasks => { ServiceTask => {
                Id => 401,
                ServiceTaskSchedules => { ServiceTaskSchedule => {
                    ScheduleDescription => 'every other Wednesday',
                    StartDate => { DateTime => '2020-01-01T00:00:00Z' },
                    EndDate => { DateTime => '2050-01-01T00:00:00Z' },
                    NextInstance => {
                        CurrentScheduledDate => { DateTime => '2020-06-03T00:00:00Z' },
                        OriginalScheduledDate => { DateTime => '2020-06-03T00:00:00Z' },
                    },
                    LastInstance => {
                        OriginalScheduledDate => { DateTime => '2020-05-27T00:00:00Z' },
                        CurrentScheduledDate => { DateTime => '2020-05-27T00:00:00Z' },
                        Ref => { Value => { anyType => [ 123, 456 ] } },
                    },
                } },
            } },
        }, {
            Id => 1002,
            ServiceId => 262,
            ServiceName => 'Domestic Refuse Collection',
            ServiceTasks => { ServiceTask => {
                Id => 36384495,
                ServiceTaskSchedules => { ServiceTaskSchedule => {
                    ScheduleDescription => 'Wednesday every other week',
                    Allocation => {
                        RoundName => 'Wednesday',
                        RoundGroupName => 'Delta 12 Week 2',
                    },
                    StartDate => { DateTime => '2020-01-01T00:00:00Z' },
                    EndDate => { DateTime => '2050-01-01T00:00:00Z' },
                    NextInstance => {
                        CurrentScheduledDate => { DateTime => '2020-06-10T00:00:00Z' },
                        OriginalScheduledDate => { DateTime => '2020-06-10T00:00:00Z' },
                    },
                    LastInstance => {
                        OriginalScheduledDate => { DateTime => '2020-05-27T00:00:00Z' },
                        CurrentScheduledDate => { DateTime => '2020-05-27T00:00:00Z' },
                        Ref => { Value => { anyType => [ 234, 567 ] } },
                    },
                } },
            } },
        }, {
            Id => 1003,
            ServiceId => 316,
            ServiceName => 'Domestic Food Waste Collection',
            ServiceTasks => { ServiceTask => {
                Id => 403,
                ScheduleDescription => 'every Thursday fortnightly',
                ServiceTaskSchedules => { ServiceTaskSchedule => {
                    ScheduleDescription => 'every other Thursday',
                    StartDate => { DateTime => '2020-01-01T00:00:00Z' },
                    EndDate => { DateTime => '2050-01-01T00:00:00Z' },
                    NextInstance => {
                        CurrentScheduledDate => { DateTime => '2020-06-04T00:00:00Z' },
                        OriginalScheduledDate => { DateTime => '2020-06-04T00:00:00Z' },
                    },
                    LastInstance => {
                        OriginalScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                        CurrentScheduledDate => { DateTime => '2020-05-21T00:00:00Z' },
                        Ref => { Value => { anyType => [ 345, 678 ] } },
                    },
                    TimeBand => {
                        Start => '07:30:00.000',
                        End => '08:30:00.000',
                    },
                } },
            } },
        }, {
            Id => '36404180',
            ServiceId => 807,
            ServiceName => 'Domestic Paper/Card Collection',
            ServiceTasks => { ServiceTask => {
                Id => 21507618,
                TaskTypeId => 4317,
                Data => '',
                ServiceTaskSchedules => { ServiceTaskSchedule => [ {
                    ScheduleDescription => 'every other Wednesday',
                    Allocation => {
                        RoundName => 'Wednesday',
                        RoundGroupName => 'PaperCard07 WKB',
                    },
                    StartDate => { DateTime => '2020-03-30T00:00:00Z' },
                    EndDate => { DateTime => '2050-01-01T00:00:00Z' },
                    NextInstance => {
                        CurrentScheduledDate => { DateTime => '2020-06-01T00:00:00Z' },
                        OriginalScheduledDate => { DateTime => '2020-06-01T00:00:00Z' },
                    },
                    LastInstance => {
                        OriginalScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                        CurrentScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                        Ref => { Value => { anyType => [ 567, 890 ] } },
                    },
                } ] },
            } }
        },{
            Id => 1004,
            ServiceId => 317,
            ServiceName => 'Garden waste collection',
            ServiceTasks => { ServiceTask => {
                Id => 405,
                TaskTypeId => 1689,
                Data => { ExtensibleDatum => [ {
                    DatatypeName => 'BRT - Paid Collection Container Quantity',
                    Value => 1,
                }, {
                    DatatypeName => 'BRT - Paid Collection Container Type',
                    Value => 1,
                } ] },
                ServiceTaskSchedules => { ServiceTaskSchedule => [ {
                    ScheduleDescription => 'every other Monday',
                    Allocation => {
                        RoundName => 'Monday ',
                        RoundGroupName => 'Delta 04 Week 2',
                    },
                    StartDate => { DateTime => '2020-03-30T00:00:00Z' },
                    EndDate => { DateTime => '2050-01-01T00:00:00Z' },
                    NextInstance => {
                        CurrentScheduledDate => { DateTime => '2020-06-01T00:00:00Z' },
                        OriginalScheduledDate => { DateTime => '2020-06-01T00:00:00Z' },
                    },
                    LastInstance => {
                        OriginalScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                        CurrentScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                        Ref => { Value => { anyType => [ 567, 890 ] } },
                    },
                } ] },
            } }
        }, ]
    });

    my $sent_params = {};
    my $call_params = {};

    my $pay = Test::MockModule->new('Integrations::SCP');
    $pay->mock(call => sub {
        my $self = shift;
        my $method = shift;
        $call_params = { @_ };
    });
    $pay->mock(pay => sub {
        my $self = shift;
        $sent_params = shift;
        $pay->original('pay')->($self, $sent_params);
        return {
            transactionState => 'IN_PROGRESS',
            scpReference => '12345',
            invokeResult => {
                status => 'SUCCESS',
                redirectUrl => 'http://example.org/faq'
            }
        };
    });
    $pay->mock(query => sub {
        my $self = shift;
        $sent_params = shift;
        return {
            transactionState => 'COMPLETE',
            paymentResult => {
                status => 'SUCCESS',
                paymentDetails => {
                    paymentHeader => {
                        uniqueTranId => 54321
                    }
                }
            }
        };
    });

    subtest 'test report missed container' => sub {
        set_fixed_time('2020-05-19T12:00:00Z'); # After sample food waste collection
        $mech->get_ok('/waste/12345');
        restore_time();
    };

    $mech->get_ok('/waste/12345');
    $mech->content_contains("(07:30&ndash;08:30)", 'shows time band');
    $mech->content_contains('https://example.org/media/16420712/wednesdayweek2', 'showing PDF calendar');
    $mech->content_contains('https://example.org/media/16420712/mondayweek2', 'showing green garden waste PDF calendar');
    $mech->content_contains('every Thursday', 'food showing right schedule');

    subtest 'test requesting a container' => sub {
        set_fixed_time('2025-01-27T12:00:00Z'); # After new general bin notice text
        $mech->log_in_ok($user1->email);
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Request a recycling container');
        $mech->follow_link_ok({url => 'http://brent.fixmystreet.com/waste/12345/request'});

        $mech->submit_form_ok({ with_fields => { 'container-choice' => 16 } }, "Choose refuse bin");
        $mech->content_contains('Apply for a new/replacement refuse bin');
        $mech->back;

        $mech->submit_form_ok({ with_fields => { 'container-choice' => 13 } }, "Choose garden bin");
        $mech->content_contains("Why do you need a replacement container?");
        $mech->content_contains("My container is damaged", "Can report damaged container");
        $mech->content_contains("My container is missing", "Can report missing container");
        $mech->content_lacks("I am a new resident without a container", "Can request new container as new resident");
        $mech->content_lacks("I would like an extra container", "Can not request an extra container");
        $mech->submit_form_ok({ with_fields => { 'request_reason' => 'damaged' } }, "Choose damaged as replacement reason");
        $mech->content_contains("About you");

        for my $test ({ id => 11, name => 'food waste caddy'}, { id => 6, name => 'Recycling bin (blue bin)'}) {
            $mech->get_ok('/waste/12345');
            $mech->follow_link_ok({url => 'http://brent.fixmystreet.com/waste/12345/request'});
            $mech->submit_form_ok({ with_fields => { 'container-choice' => $test->{id} } }, "Choose " . $test->{name});
            $mech->content_contains("Why do you need a replacement container?");
            $mech->content_contains("My container is damaged", "Can report damaged container");
            $mech->content_contains("My container is missing", "Can report missing container");
            $mech->content_contains("I am a new resident without a container", "Can request new container as new resident");
            $mech->content_contains("I would like an extra container", "Can request an extra container");
            for my $radio (
                    {choice => 'damaged', type => 'damaged container'},
                    {choice => 'missing', type => 'missing container'},
                    {choice => 'extra', type => 'extra container'}
            ) {
                $mech->submit_form_ok({ with_fields => { 'request_reason' => $radio->{choice} } });
                $mech->content_contains("About you", "No further questions for " . $radio->{type});
                $mech->back;
            }
            for my $radio (
                    {choice => 'new_build', type => 'new resident needs container'},
            ) {
                $mech->submit_form_ok({ with_fields => { 'request_reason' => $radio->{choice} } });
                $mech->content_contains("How long have you", "Extra question for " . $radio->{type});
                $mech->back;
            }
            $mech->back;
        }

        $mech->submit_form_ok({ with_fields => { 'container-choice' => 13 } }, "Choose garden bin");
        $mech->submit_form_ok({ with_fields => { 'request_reason' => 'damaged' } });
        $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => $user1->email } });
        $mech->submit_form_ok({ with_fields => { 'process' => 'summary' } });
        $mech->content_contains('Your container request has been sent');
        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        is $report->get_extra_field_value('uprn'), 1000000002;
        is $report->get_extra_field_value('Container_Request_Container_Type'), '13::13';
        is $report->get_extra_field_value('Container_Request_Action'), '2::1';
        is $report->get_extra_field_value('Container_Request_Reason'), '4::4';
        is $report->get_extra_field_value('Container_Request_Notes'), '';
        is $report->get_extra_field_value('Container_Request_Quantity'), '1::1';
        is $report->get_extra_field_value('service_id'), '317';

        FixMyStreet::Script::Reports::send();
        # No sent email, only logged email
        my $body = $mech->get_text_body_from_email;
        like $body, qr/We aim to deliver this container/;
        restore_time();
    };

    subtest 'test requesting a container with payment' => sub {
        for my $test (
            # { id => 11, name => 'food waste caddy', service_id => 316, pence_cost => 500 },
            { id => 6, name => 'Recycling bin (blue bin)', service_id => 265, pence_cost => 3000 },
        ) {
            subtest "...a $test->{name}" => sub {
                $mech->get_ok('/waste/12345');
                $mech->follow_link_ok({url => 'http://brent.fixmystreet.com/waste/12345/request'});
                $mech->submit_form_ok({ with_fields => { 'container-choice' => $test->{id} } }, "Choose " . $test->{name});
                $mech->submit_form_ok({ with_fields => { 'request_reason' => 'damaged' } });
                $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => $user1->email } });
                $mech->content_contains('Continue to payment');
                $mech->waste_submit_check({ with_fields => { 'process' => 'summary' } });

                my ( $token, $report, $report_id ) = get_report_from_redirect( $sent_params->{returnUrl} );

                is $sent_params->{items}[0]{amount}, $test->{pence_cost}, 'correct amount used';
                # The below does a similar checks to the garden test check_extra_data_pre_confirm
                is $report->category, 'Request new container', 'correct category on report';
                is $report->title, "Request new \u$test->{name}", 'correct title on report';
                is $report->get_extra_field_value('payment_method'), 'credit_card', 'correct payment method on report';
                is $report->get_extra_field_value('uprn'), 1000000002;
                is $report->get_extra_field_value('Container_Request_Container_Type'), join('::', $test->{id}, $test->{id});
                is $report->get_extra_field_value('Container_Request_Action'), '2::1';
                is $report->get_extra_field_value('Container_Request_Reason'), '4::4';
                is $report->get_extra_field_value('Container_Request_Notes'), '';
                is $report->get_extra_field_value('Container_Request_Quantity'), '1::1';
                is $report->get_extra_field_value('service_id'), $test->{service_id};

                is $report->state, 'unconfirmed', 'report state correct';
                is $report->get_extra_metadata('scpReference'), '12345', 'correct scp reference on report';

                $mech->get_ok("/waste/pay_complete/$report_id/$token");

                # The below does a similar checks to the garden test check_extra_data_post_confirm
                $report->discard_changes;
                is $report->state, 'confirmed', 'report confirmed';
                is $report->get_extra_field_value('PaymentCode'), '54321', 'correct echo payment reference field';
                is $report->get_extra_metadata('payment_reference'), '54321', 'correct payment reference on report';

                $mech->content_contains('Your container request has been sent');
                $mech->content_like(qr#/waste/12345"[^>]*>Show upcoming#, "contains link to bin page");

                FixMyStreet::Script::Reports::send();
                my $body = $mech->get_text_body_from_email;
                like $body, qr/We aim to deliver this container/;
                $mech->clear_emails_ok;
            };
        }
    };

    sub make_request {
        my ($test_name, $reason, $duration, $referral, $emails) = @_;
        my $full_test_name = "Making a request, $test_name, $reason" . ($duration ? ", $duration" : "");
        subtest $full_test_name => sub {
            $mech->get_ok('/waste/12345/request');
            $mech->submit_form_ok({ with_fields => { 'container-choice' => 11 } }, "Choose food caddy");
            $mech->submit_form_ok({ with_fields => { 'request_reason' => $reason } });
            $mech->submit_form_ok({ with_fields => { how_long_lived => $duration } }) if $duration;
            if ($referral eq 'refuse') {
                $mech->content_contains('referral@example.org');
                return;
            }
            $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => $user1->email } });
            # if ($referral) {
                $mech->submit_form_ok({ with_fields => { 'process' => 'summary' } });
                $mech->content_contains('Your container request has been sent');
            # } else {
            #     $mech->waste_submit_check({ with_fields => { 'process' => 'summary' } });
            # }
            my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
            if (!$referral) {
                $report->update({ state => 'confirmed' }); # Fake payment
            }
            is $report->get_extra_field_value('request_referral'), $referral;
            is $report->get_extra_field_value('request_how_long_lived'), $duration;
            is $report->get_extra_field_value('request_ordered_previously'), $test_name eq 'Ordered' ? 1 : '';
            is $report->get_extra_field_value('request_contamination_reports'), $test_name eq 'Contaminated' ? 3 : '';
            FixMyStreet::Script::Reports::send();
            my @email = $mech->get_email;
            is @email, $emails;
            if ($emails == 2) {
                like $mech->get_text_body_from_email($email[0]), qr/a resident has tried to request a container/;
                like $mech->get_text_body_from_email($email[1]), qr/We aim to deliver this container/;
            } else {
                like $mech->get_text_body_from_email($email[0]), qr/We aim to deliver this container/;
            }
            $mech->clear_emails_ok;
            $report->delete;
        };
    }

    subtest 'check request referral/refusal' => sub {
        $echo->mock('GetEventsForObject', sub { [ {
            Guid => 'a-guid',
            EventTypeId => 2936,
            ResolvedDate => { DateTime => '2024-05-17T12:00:00Z' },
            Data => { ExtensibleDatum => { ChildData => { ExtensibleDatum => {
                DatatypeName => 'Container Type',
                Value => 11,
            } } } },
        } ] } );
        make_request("Ordered", 'new_build', 'less3', 1, 2);
        make_request("Ordered", 'damaged', '', 1, 2);
        make_request("Ordered", 'missing', '', 1, 2);
        make_request("Ordered", 'extra', '', 'refuse');

        $echo->mock('GetEventsForObject', sub { [] });
        make_request("Not ordered", 'new_build', 'less3', '', 1);
        make_request("Not ordered", 'new_build', '3more', 1, 2);
        make_request("Not ordered", 'missing', '', '', 1);
        make_request("Not ordered", 'extra', '', '', 1);

        # $echo->mock('GetServiceTaskInstances', sub { [
        #     { ServiceTaskRef => { Value => { anyType => '401' } },
        #         Instances => { ScheduledTaskInfo => [
        #             { Resolution => 1148, CurrentScheduledDate => { DateTime => '2020-07-01T00:00:00Z' } },
        #             { Resolution => 1148, CurrentScheduledDate => { DateTime => '2020-07-01T00:00:00Z' } },
        #             { Resolution => 1148, CurrentScheduledDate => { DateTime => '2020-07-01T00:00:00Z' } },
        #         ] }
        #     },
        # ] });
        # make_request("Contaminated", 'missing', '', 1, 2);
        # make_request("Contaminated", 'extra', '', 'refuse');
    };

    subtest 'test staff-only assisted collection form' => sub {
        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Set up for assisted collection');
        $mech->get_ok('/waste/12345/enquiry?category=Assisted+collection+add&service_id=262');
        $mech->submit_form_ok({ with_fields => { extra_Notes => 'Behind the garden gate' } });
        $mech->submit_form_ok({ with_fields => { name => "Anne Assist", email => 'anne@example.org' } });
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('enquiry has been submitted');
        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        is $report->detail, "Behind the garden gate\n\n2 Example Street, Brent, NW2 1AA";
        is $report->user->email, 'anne@example.org';
        is $report->name, 'Anne Assist';
    };

    subtest 'test staff-only additional collection form' => sub {
        $mech->log_in_ok($user1->email);
        $mech->get_ok('/waste/12345');
        $mech->content_lacks('Log an additional collection');
        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Log an additional collection');
        $mech->get_ok('/waste/12345/enquiry?category=Additional+collection&service_id=262');
        $mech->submit_form_ok({ with_fields => { extra_Notes => 'Please do another collection for this address' } });
        $mech->submit_form_ok({ with_fields => { name => "Anne Assist", email => 'anne@example.org' } });
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('enquiry has been submitted');
        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        is $report->detail, "Please do another collection for this address\n\n2 Example Street, Brent, NW2 1AA";
        is $report->user->email, 'anne@example.org';
        is $report->name, 'Anne Assist';
    };

    subtest 'test staff-only general enquiry form' => sub {
        $mech->log_in_ok($user1->email);
        $mech->get_ok('/waste/12345');
        $mech->content_lacks('Staff general enquiry');
        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Staff general enquiry');
        $mech->get_ok('/waste/12345/enquiry?category=Staff+general+enquiry&service_id=265');
        $mech->submit_form_ok({ with_fields => { extra_Notes => 'Domestic rubbish often missed at this address' } });
        $mech->submit_form_ok({ with_fields => { name => "Staff User", email => 'staff@example.org' } });
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('enquiry has been submitted');
        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        is $report->detail, "Domestic rubbish often missed at this address\n\n2 Example Street, Brent, NW2 1AA";
        is $report->user->email, 'staff@example.org';
        is $report->name, 'Staff User';
        is $report->get_extra_field_value('service_id'), '265';
        $report->delete;
        $report->update;
    };

    $echo->mock('GetServiceUnitsForObject' => sub {
    return [
        {
            Id => 1001,
            ServiceId => 269,
            ServiceName => 'FAS DMR Collection',
            ServiceTasks => { ServiceTask => {
                Id => 401,
                ServiceTaskSchedules => { ServiceTaskSchedule => {
                    ScheduleDescription => 'every other Wednesday',
                    StartDate => { DateTime => '2020-01-01T00:00:00Z' },
                    EndDate => { DateTime => '2050-01-01T00:00:00Z' },
                    NextInstance => {
                        CurrentScheduledDate => { DateTime => '2020-06-03T00:00:00Z' },
                        OriginalScheduledDate => { DateTime => '2020-06-03T00:00:00Z' },
                    },
                } },
            } },
        }, ]
    });
    subtest 'test requesting a sack' => sub {
        # Ordered previously, but not referred
        $echo->mock('GetEventsForObject', sub { [ {
            Guid => 'a-guid',
            EventTypeId => 2936,
            ResolvedDate => { DateTime => '2024-05-17T12:00:00Z' },
            Data => { ExtensibleDatum => { ChildData => { ExtensibleDatum => {
                DatatypeName => 'Container Type',
                Value => 8,
            } } } },
        } ] } );
        $mech->get_ok('/waste/12345');
        $mech->follow_link_ok({url => 'http://brent.fixmystreet.com/waste/12345/request'});
        $mech->submit_form_ok({ with_fields => { 'container-choice' => 8 } }, "Choose sack");
        $mech->content_contains("Why do you need more sacks?");
        $mech->content_lacks("My container is damaged", "Can report damaged container");
        $mech->content_lacks("My container is missing", "Can report missing container");
        $mech->content_contains("I am a new resident without any", "Can request new container as new resident");
        $mech->content_contains("I have used all the sacks provided", "Can request more sacks");
        $mech->submit_form_ok({ with_fields => { 'request_reason' => 'new_build' } });
        $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => $user1->email } });
        $mech->submit_form_ok({ with_fields => { 'process' => 'summary' } });
        $mech->content_contains('Your container request has been sent');
        my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
        is $report->get_extra_field_value('uprn'), 1000000002;
        is $report->get_extra_field_value('Container_Request_Container_Type'), '8';
        is $report->get_extra_field_value('Container_Request_Action'), '1';
        is $report->get_extra_field_value('Container_Request_Reason'), '6';
        is $report->get_extra_field_value('Container_Request_Notes'), '';
        is $report->get_extra_field_value('Container_Request_Quantity'), '1';
        is $report->get_extra_field_value('service_id'), '269';
        is $report->get_extra_field_value('request_referral'), '';
    };
    $echo->mock('GetServiceUnitsForObject' => sub {
    return [
        {
            Id => 1004,
            ServiceId => 317,
            ServiceName => 'Garden waste collection',
            ServiceTasks => { ServiceTask => {
                Id => 405,
                TaskTypeId => 1689,
                Data => { ExtensibleDatum => [ {
                    DatatypeName => 'BRT - Paid Collection Container Quantity',
                    Value => 1,
                }, {
                    DatatypeName => 'BRT - Paid Collection Container Type',
                    Value => 1,
                } ] },
                ServiceTaskSchedules => { ServiceTaskSchedule => [ {
                    ScheduleDescription => 'Monday every 4th week',
                    Allocation => {
                        RoundName => 'Monday ',
                        RoundGroupName => 'Delta 04 Week 2',
                    },
                    StartDate => { DateTime => '2020-03-30T00:00:00Z' },
                    EndDate => { DateTime => '2050-01-01T00:00:00Z' },
                    NextInstance => {
                        CurrentScheduledDate => { DateTime => '2020-06-01T00:00:00Z' },
                        OriginalScheduledDate => { DateTime => '2020-06-01T00:00:00Z' },
                    },
                    LastInstance => {
                        OriginalScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                        CurrentScheduledDate => { DateTime => '2020-05-18T00:00:00Z' },
                        Ref => { Value => { anyType => [ 567, 890 ] } },
                    },
                } ] },
            } }
        }, ]
    });
    subtest 'test variation in ScheduleDescription in winter months' => sub {
        $mech->get_ok('/waste/12345');
        $mech->content_contains('https://example.org/media/16420712/mondayweek2', 'showing green garden waste PDF calendar');
    }
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
    ok $mech->content_contains('"Created By",Email,USRN,UPRN,"External ID","Does the report have an image?","Extra details","Inspection date","Grade for Litter","Grade for Detritus","Grade for Graffiti","Grade for Fly-posting","Grade for Weeds","Overall Grade","Did you see the fly-tipping take place","If \'Yes\', are you willing to provide a statement?","How much waste is there","Type of waste","Container Request Action","Container Request Container Type","Container Request Reason","Email Renewal Reminders Opt-In","Service ID","Staff Role","Small Item 1","Small Item 2"', "New columns added");
    ok $mech->content_like(qr/Flexible problem.*?"Test User",pkg-tcobrandbrentt/, "User and email added");
    ok $mech->content_like(qr/Flexible problem.*?,,,,Y,,,,,,,,/, "All fields empty but photo exists");
    $flexible_problem->set_extra_fields(
        {name => 'Container_Request_Action', value => 1},
        {name => 'Container_Request_Container_Type', value => 1},
        {name => 'Container_Request_Reason', value => 1},
        {name => 'service_id', value => 1},
        {name => 'usrn', value => 1234},
        {name => 'uprn', value => 4321},
    );
    $flexible_problem->external_id('121');
    $flexible_problem->update;
    $mech->get_ok('/dashboard?export=1');
    ok $mech->content_like(qr/Flexible problem.*?,1234,4321,121,Y,,,,,,,,,,,,,Deliver,"Blue rubbish sack",Missing,,1/, "Bin request values added");
    $flexible_problem->category('Fly-tipping');
    $flexible_problem->set_extra_fields(
        {name => 'Did_you_see_the_Flytip_take_place?_', value => 1},
        {name => 'Are_you_willing_to_be_a_WItness?_', value => 0},
        {name => 'Flytip_Size', value => 4},
        {name => 'Flytip_Type', value => 13},
    );
    $flexible_problem->update;
    $mech->get_ok('/dashboard?export=1');
    ok $mech->content_like(qr/Flexible problem.*?,121,Y,,,,,,,,,Yes,No,"Small van load",Appliance,/, "Flytip request values added");
    $flexible_problem->set_extra_fields(
        {name => 'location_name', value => 'Test Park'},
    );
    $flexible_problem->update;
    $mech->get_ok('/dashboard?export=1');
    ok $mech->content_like(qr/Flexible problem.*?,,,"Test Park","Test User",.*?,,,121,Y,,,,,,,,,,,,,,,,,,/, "Location name added") or diag $mech->content;
    $flexible_problem->set_extra_metadata('item_1' => 'Sofa', 'item_2' => 'Wardrobe');
    $flexible_problem->update;
    $mech->get_ok('/dashboard?export=1');
    ok $mech->content_like(qr/Flexible problem.*?,,,"Test Park","Test User",.*?,,,121,Y,,,,,,,,,,,,,,,,,,,Sofa,Wardrobe,,,,,,,/, "Bulky items added") or diag $mech->content;
    $flexible_problem->set_extra_metadata('contributed_by' => $staff_user->id);
    $flexible_problem->update;
    $mech->get_ok('/dashboard?export=1');
    ok $mech->content_like(qr/Flexible problem.*?,,,"Test Park","Test User",.*?,,,121,Y,,,,,,,,,,,,,,,,,,Role,Sofa,Wardrobe,,,,,,,/, "Role added") or diag $mech->content;
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
        {name => 'uprn', value => 4321},
    );
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
    $mech->content_contains('"Created By",Email,USRN,UPRN,"External ID","Does the report have an image?","Extra details","Inspection date","Grade for Litter","Grade for Detritus","Grade for Graffiti","Grade for Fly-posting","Grade for Weeds","Overall Grade","Did you see the fly-tipping take place","If \'Yes\', are you willing to provide a statement?","How much waste is there","Type of waste","Container Request Action","Container Request Container Type","Container Request Reason","Email Renewal Reminders Opt-In","Service ID","Staff Role","Small Item 1","Small Item 2"', "New columns added");
    $mech->content_like(qr/Pregen problem Test 3.*?"Test User",pkg-tcobrandbrentt/, "User and email added");
    $mech->content_like(qr/Pregen problem Test 3.*?,1234,4321,121,Y,,,,,,,,,,,,,Collect\+Deliver,"Food waste caddy",Damaged,,1/, "Bin request values added");
    $mech->content_like(qr/Pregen problem Test 2.*?,,Y,,,,,,,,,Yes,No,"Small van load",Appliance,/, "Flytip request values added");
    $mech->content_like(qr/Pregen problem Test 1.*?,,,"Test Park","Test User",.*?,,,,Y,,,,,,,,,,,,,,,,,,,Sofa,Wardrobe,,,,,,,/, "Bulky items added");
    $problems[2]->set_extra_metadata('contributed_by' => $staff_user->id);
    $problems[2]->update;
    FixMyStreet::Script::CSVExport::process(dbh => FixMyStreet::DB->schema->storage->dbh);
    $mech->get_ok('/dashboard?export=1');
    $mech->content_like(qr/Pregen problem Test 1.*?,,,"Test Park","Test User",.*?,,,,Y,,,,,,,,,,,,,,,,,,Role,Sofa,Wardrobe,,,,,,,/, "Role added");
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
