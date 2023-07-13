use CGI::Simple;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use t::Mock::Tilma;
use Test::MockTime qw(:all);
use Test::MockModule;
use Test::Output;

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
}, {
    cobrand => 'brent'
});
my $atak_contact = $mech->create_contact_ok(body_id => $brent->id, category => 'ATAK', email => 'ATAK');

FixMyStreet::DB->resultset('BodyArea')->find_or_create({
    area_id => 2505, # Camden
    body_id => $brent->id,
});

my $camden = $mech->create_body_ok(2505, 'Camden Borough Council', {},{cobrand => 'camden'});
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
my $staff_user = $mech->create_user_ok('staff@example.org', from_body => $brent, name => 'Staff User');

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

create_contact({ category => 'Fly-tipping', email => 'flytipping@brent.example.org' },
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

create_contact({ category => 'Report missed collection', email => 'missed' });
create_contact({ category => 'Request new container', email => 'request@example.org' },
    { code => 'Container_Request_Quantity', required => 1, automated => 'hidden_field' },
    { code => 'Container_Request_Container_Type', required => 1, automated => 'hidden_field' },
    { code => 'Container_Request_Action', required => 0, automated => 'hidden_field' },
    { code => 'Container_Request_Notes', required => 0, automated => 'hidden_field' },
    { code => 'Container_Request_Reason', required => 0, automated => 'hidden_field' },
    { code => 'service_id', required => 0, automated => 'hidden_field' },
    { code => 'LastPayMethod', required => 0, automated => 'hidden_field' },
    { code => 'PaymentCode', required => 0, automated => 'hidden_field' },
    { code => 'payment_method', required => 1, automated => 'hidden_field' },
    { code => 'payment', required => 1, automated => 'hidden_field' },
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
        $problem->update;

        FixMyStreet::override_config {
            ALLOWED_COBRANDS => 'brent',
            MAPIT_URL        => 'http://mapit.uk/',
            STAGING_FLAGS    => { send_reports => 1 },
            COBRAND_FEATURES =>
                { anonymous_account => { brent => 'anonymous' }, },
        }, sub {
            FixMyStreet::Script::Reports::send();
            my $req = Open311->test_req_used;
            my $c   = CGI::Simple->new( $req->content );
            is $c->param('attribute[UnitID]'), undef,
                'UnitID removed from attributes';
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

my $tilma = t::Mock::Tilma->new;
LWP::Protocol::PSGI->register($tilma->to_psgi_app, host => 'tilma.mysociety.org');

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
        $mech->create_contact_ok(body_id => $tfl->id, category => 'Sweeping', email => 'tfl@example.org');
        ok $mech->host('brent.fixmystreet.com'), 'set host';
        my $json = $mech->get_ok_json('/report/new/ajax?latitude=51.55904&longitude=-0.28168');
        is $json->{by_category}->{"River Piers"}, undef, "Brent doesn't have River Piers category";
        is $json->{by_category}->{"River Piers - Cleaning"}, undef, "Brent doesn't have River Piers with hyphen and extra text category";
        is $json->{by_category}->{"River Piers Damage doors and glass"}, undef, "Brent doesn't have River Piers with extra text category";
    };

    subtest "has the correct pin colours" => sub {
        my $cobrand = $brent->get_cobrand_handler;

        my ($problem) = $mech->create_problems_for_body(1, $brent->id, 'Title', {
            areas => '2488', category => 'Graffiti', cobrand => 'brent', user => $user1
        });

        $problem->state('confirmed');
        is $cobrand->pin_colour($problem, 'around'), 'yellow', 'confirmed problem has correct pin colour';

        $problem->state('closed');
        is $cobrand->pin_colour($problem, 'around'), 'grey', 'closed problem has correct pin colour';

        $problem->state('fixed');
        is $cobrand->pin_colour($problem, 'around'), 'green', 'fixed problem has correct pin colour';

        $problem->state('in_progress');
        is $cobrand->pin_colour($problem, 'around'), 'orange', 'in_progress problem has correct pin colour';
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
                    $mech->get_ok("/report/new/ajax?longitude=-0.28168&latitude=51.55904");
                    is $mech->content_contains("Potholes"), 1, 'Brent category present';
                    is $mech->content_lacks("Gully grid missing"), 1, 'Brent Symology category not present';
                    is $mech->content_contains("Sweeping"), 1, 'TfL category present';
                    is $mech->content_contains("Fly-tipping"), 1, 'Camden category present';
                    is $mech->content_lacks("Dead animal"), 1, 'Camden non-street category not present';
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
                        sub { [ { 'ms:BrentDiffs' => { 'ms:name' => 'Brent' } } ] });
                    $mech->get_ok("/report/new/ajax?longitude=-0.124514&latitude=51.529432");
                    is $mech->content_lacks("Potholes"), 1, 'Brent category not present';
                    is $mech->content_contains("Gully grid missing"), 1, 'Brent Symology category present';
                    is $mech->content_contains("Sweeping"), 1, 'TfL category present';
                    is $mech->content_lacks("Fly-tipping"), 1, 'Camden street category not present';
                    is $mech->content_contains("Dead animal"), 1, 'Camden non-street category present';
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

            subtest "can access Brent from Camden on Camden asset layer" => sub {
                $mech->host("camden.fixmystreet.com");
                $camden_mock->mock('_fetch_features', sub { [{ 'ms:BrentDiffs' => { 'ms:name' => 'Camden' } }] });
                $mech->get_ok("/report/new?longitude=-0.28168&latitude=51.55904");
                is $mech->content_lacks('That location is not covered by Camden Council'), 1, "Can make a report on Camden asset";
            };

            subtest "can not access Brent from Camden not on asset layer" => sub {
                $mech->host("camden.fixmystreet.com");
                $camden_mock->mock('_fetch_features', sub { [] });
                $mech->get_ok("/report/new?longitude=-0.28168&latitude=51.55904");
                is $mech->content_contains('That location is not covered by Camden Council'), 1, "Can make a report on Camden asset";
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

            $mech->host("brent.fixmystreet.com");
            undef $brent_mock; undef $camden_mock;
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

        $update = $report->comments->search(undef, { order_by => { -desc => 'id' } })->first;
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

        $update = $report->comments->search(undef, { order_by => { -desc => 'id' } })->first;
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
        is $report->comments->count, 4, 'A new update';
        $report->discard_changes;
        is $report->state, 'closed', 'A state change';

        my $update = $report->comments->search(undef, { order_by => { -desc => 'id' } })->first;
        my $sent = FixMyStreet::DB->resultset("AlertSent")->search({ alert_id => $alert->id, parameter => $update->id })->first;
        is $sent, undef;

        $report->update({ state => 'confirmed' });
        $in =~ s/943/1159/;
        $in =~ s/7672/7680/;
        $mech2->post('/waste/echo', Content_Type => 'text/xml', Content => $in);
        is $report->comments->count, 5, 'A new update';
        $report->discard_changes;
        is $report->state, 'fixed - council', 'A state change';

        $update = $report->comments->search(undef, { order_by => { -desc => 'id' } })->first;
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
    ALLOWED_COBRANDS => [ 'brent' ],
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
                category => 'Parks and open spaces',
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
                category => 'Parks and open spaces',
                'category.Parksandopenspaces' => 'Overgrown grass',
            }
        }, "submit details");
        $mech->content_contains('Your issue is on its way to the council') or diag $mech->content;

        FixMyStreet::Script::Reports::send();

        # Get the most recent report
        my $report = FixMyStreet::DB->resultset('Problem')->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->get_extra_field_value('location_name'), 'King Edward VII Park, Wembley', 'Location name is set';
    };

    subtest "Doesn't overwrite location_name if already set" => sub {
        $mech->get_ok('/report/new?latitude=51.55904&longitude=-0.28168');
        $mech->submit_form_ok({
            with_fields => {
                title => "Test Report",
                detail => 'Test report details.',
                category => 'Parks and open spaces',
                'category.Parksandopenspaces' => 'Overgrown grass',
            }
        }, "submit details");
        $mech->content_contains('Your issue is on its way to the council') or diag $mech->content;


        # Get the most recent report and set the location_name
        my $report = FixMyStreet::DB->resultset('Problem')->search(undef, { order_by => { -desc => 'id' } })->first;
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
                category => 'Parks and open spaces',
                'category.Parksandopenspaces' => 'Ponds',
            }
        }, "submit details");
        $mech->content_contains('Your issue is on its way to the council') or diag $mech->content;

        FixMyStreet::Script::Reports::send();

        # Get the most recent report
        my $report = FixMyStreet::DB->resultset('Problem')->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->get_extra_field_value('location_name'), 'King Edward VII Park, Wembley', 'Location name is set';
    };
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'brent',
    MAPIT_URL => 'http://mapit.uk/',
    COBRAND_FEATURES => {
        echo => { brent => { sample_data => 1 } },
        waste => { brent => 1 },
        anonymous_account => { brent => 'anonymous' },
        waste_calendar_links => { brent => {
            'wednesday-B2' => 'https://example.org/media/16420712/wednesdayweek2.pdf'
        } },
        ggw_calendar_links => { brent => {
            'monday-2' => 'https://example.org/media/16420712/mondayweek2'
        } },
        payment_gateway => { brent => {
            cc_url => 'http://example.com',
            ggw_cost => 6000,
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
        $mech->log_in_ok($user1->email);
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Request a recycling container');
        $mech->follow_link_ok({url => 'http://brent.fixmystreet.com/waste/12345/request'});

        $mech->submit_form_ok({ with_fields => { 'container-choice' => 16 } }, "Choose refuse bin");
        $mech->content_contains('please call');
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
                    {choice => 'new_build', type => 'new resident needs container'},
                    {choice => 'damaged', type => 'damaged container'},
                    {choice => 'missing', type => 'missing container'},
                    {choice => 'extra', type => 'extra container'}
            ) {
                $mech->submit_form_ok({ with_fields => { 'request_reason' => $radio->{choice} } });
                $mech->content_contains("About you", "No further questions for " . $radio->{type});
                $mech->back;
            }
        }

        $mech->submit_form_ok({ with_fields => { 'request_reason' => 'damaged' } });
        $mech->submit_form_ok({ with_fields => { name => "Test McTest", email => $user1->email } });
        $mech->submit_form_ok({ with_fields => { 'process' => 'summary' } });
        $mech->content_contains('Your container request has been sent');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->get_extra_field_value('uprn'), 1000000002;
        is $report->get_extra_field_value('Container_Request_Container_Type'), '6::6';
        is $report->get_extra_field_value('Container_Request_Action'), '2::1';
        is $report->get_extra_field_value('Container_Request_Reason'), '4::4';
        is $report->get_extra_field_value('Container_Request_Notes'), '';
        is $report->get_extra_field_value('Container_Request_Quantity'), '1::1';
        is $report->get_extra_field_value('service_id'), '265';
    };

    subtest 'test staff-only assisted collection form' => sub {
        $mech->log_in_ok($staff_user->email);
        $mech->get_ok('/waste/12345');
        $mech->content_contains('Set up for assisted collection');
        $mech->get_ok('/waste/12345/enquiry?category=Assisted+collection+add&service_id=262');
        $mech->submit_form_ok({ with_fields => { extra_Notes => 'Behind the garden gate' } });
        $mech->submit_form_ok({ with_fields => { name => "Anne Assist", email => 'anne@example.org' } });
        $mech->submit_form_ok({ with_fields => { process => 'summary' } });
        $mech->content_contains('Enquiry has been submitted');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
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
        $mech->content_contains('Enquiry has been submitted');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
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
        $mech->content_contains('Enquiry has been submitted');
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
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
        my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
        is $report->get_extra_field_value('uprn'), 1000000002;
        is $report->get_extra_field_value('Container_Request_Container_Type'), '8';
        is $report->get_extra_field_value('Container_Request_Action'), '1';
        is $report->get_extra_field_value('Container_Request_Reason'), '6';
        is $report->get_extra_field_value('Container_Request_Notes'), '';
        is $report->get_extra_field_value('Container_Request_Quantity'), '1';
        is $report->get_extra_field_value('service_id'), '269';
    };
};

subtest 'Dashboard CSV extra columns' => sub {
  FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'brent',
    MAPIT_URL => 'http://mapit.uk/',
  }, sub {
    my ($flexible_problem) = $mech->create_problems_for_body(1, $brent->id, 'Flexible problem', {
        areas => "2488", category => 'Request new container', cobrand => 'brent', user => $user1, state => 'confirmed'});
    $mech->log_in_ok( $staff_user->email );
    $mech->get_ok('/dashboard?export=1');
    ok $mech->content_contains('"Created By",Email,USRN,UPRN,"External ID","Does the report have an image?","Did you see the fly-tipping take place","If \'Yes\', are you willing to provide a statement?","How much waste is there","Type of waste","Container Request Action","Container Request Container Type","Container Request Reason","Service ID"', "New columns added");
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
    ok $mech->content_like(qr/Flexible problem.*?,1234,4321,121,Y,,,,,1,1,1,1/, "Bin request values added");
    $flexible_problem->category('Fly-tipping');
    $flexible_problem->set_extra_fields(
        {name => 'Did_you_see_the_Flytip_take_place?_', value => 1},
        {name => 'Are_you_willing_to_be_a_WItness?_', value => 0},
        {name => 'Flytip_Size', value => 4},
        {name => 'Flytip_Type', value => 13},
    );
    $flexible_problem->update;
    $mech->get_ok('/dashboard?export=1');
    ok $mech->content_like(qr/Flexible problem.*?,121,Y,Yes,No,"Small van load",Appliance,/, "Flytip request values added");
    $flexible_problem->set_extra_fields(
        {name => 'location_name', value => 'Test Park'},
    );
    $flexible_problem->update;
    $mech->get_ok('/dashboard?export=1');
    ok $mech->content_like(qr/Flexible problem.*?,,,"Test Park","Test User",.*?,,,121,Y,,,,,,,,/, "Location name added") or diag $mech->content;
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
