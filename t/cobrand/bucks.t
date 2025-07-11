use Test::MockModule;
use CGI::Simple;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;
use File::Temp 'tempdir';

use t::Mock::Tilma;
my $tilma = t::Mock::Tilma->new;
LWP::Protocol::PSGI->register($tilma->to_psgi_app, host => 'tilma.staging.mysociety.org');

my $mech = FixMyStreet::TestMech->new;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $body = $mech->create_body_ok(
    163793,
    'Buckinghamshire Council',
    {   send_method     => 'Open311',
        api_key         => 'key',
        endpoint        => 'endpoint',
        jurisdiction    => 'fms',
        can_be_devolved => 1,
        comment_user    => $mech->create_user_ok('comment_user@example.com'),
        cobrand => 'buckinghamshire',
    },
);
my $parish = $mech->create_body_ok(53822, 'Adstock Parish Council');
my $parish2 = $mech->create_body_ok(58815, 'Aylesbury Town Council');
my $deleted_parish = $mech->create_body_ok(58815, 'Aylesbury Parish Council');
$deleted_parish->update({ deleted => 1 });
my $other_body = $mech->create_body_ok(1234, 'Aylesbury Vale District Council');
my $counciluser = $mech->create_user_ok('counciluser@example.com', name => 'Council User', from_body => $body);
$counciluser->user_body_permissions->create({ body => $body, permission_type => 'triage' });
$counciluser->user_body_permissions->create({ body => $body, permission_type => 'template_edit' });
my $publicuser = $mech->create_user_ok('fmsuser@example.org', name => 'Simon Neil');

my $contact = $mech->create_contact_ok(body_id => $body->id, category => 'Flytipping', email => "FLY");
$contact->set_extra_fields({
    code => 'road-placement',
    datatype => 'singlevaluelist',
    description => 'Is the fly-tip located on',
    order => 100,
    required => 'true',
    variable => 'true',
    values => [
        { key => 'road', name => 'The road' },
        { key => 'off-road', name => 'Off the road/on a verge' },
    ],
});
$contact->update;
$mech->create_contact_ok(body_id => $body->id, category => 'Abandoned vehicles', email => 'Abavus-ABANDONED_17821_C');
$mech->create_contact_ok(body_id => $body->id, category => 'Potholes', email => "POT");
$mech->create_contact_ok(body_id => $body->id, category => 'Blocked drain', email => "DRA");
$mech->create_contact_ok(body_id => $body->id, category => 'Car Parks', email => "car\@chiltern", send_method => 'Email');
$mech->create_contact_ok(body_id => $body->id, category => 'Graffiti', email => "graffiti\@chiltern", send_method => 'Email');
$mech->create_contact_ok(body_id => $body->id, category => 'Flytipping (off-road)', email => "districts_flytipping", send_method => 'Email');
$mech->create_contact_ok(body_id => $body->id, category => 'Barrier problem', email => 'parking@example.org', send_method => 'Email', group => 'Car park issue');
my $grass_bucks = $mech->create_contact_ok(body_id => $body->id, category => 'Grass cutting', email => 'grass@example.org', send_method => 'Email');
$mech->create_contact_ok(body_id => $body->id, category => 'Flyposting', email => 'flyposting@example.org', send_method => 'Email');
$mech->create_contact_ok(body_id => $body->id, category => 'Rights of way', email => 'Cams-ROW');

# Create another Grass cutting category for a parish.
$contact = $mech->create_contact_ok(body_id => $parish->id, category => 'Grass cutting', email => 'grassparish@example.org', send_method => 'Email');
$contact->set_extra_fields({
    code => 'speed_limit_greater_than_30',
    description => 'Is the speed limit greater than 30mph?',
    datatype => 'string',
    order => 1,
    variable => 'true',
    required => 'true',
    protected => 'false',
    automated => 'hidden_field',
});
$contact->update;
$contact = $mech->create_contact_ok(body_id => $parish->id, category => 'Dirty signs', email => 'signs@example.org', send_method => 'Email');

# Create a parish "Flyposting" category with prefer_if_multiple.
$contact = $mech->create_contact_ok(body_id => $parish->id, category => 'Flyposting', email => 'flyposting-parish@example.org', send_method => 'Email');
$contact->set_extra_metadata(prefer_if_multiple => 1);
$contact->update;

FixMyStreet::DB->resultset("Config")->create({ key => 'buckinghamshire_parishes', value => [ 53822, 58815 ] });

my $UPLOAD_DIR = tempdir( CLEANUP => 1 );
FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'buckinghamshire', 'fixmystreet' ],
    MAPIT_URL => 'http://mapit.uk/',
    STAGING_FLAGS => { send_reports => 1, skip_checks => 0 },
    PHOTO_STORAGE_OPTIONS => { UPLOAD_DIR => $UPLOAD_DIR },
    COBRAND_FEATURES => {
        open311_email => {
            buckinghamshire => {
                Flytipping => [ 'flytipping@example.com', 'TfB' ],
                'Blocked drain' => [ 'floods@example.org', 'Flood Management' ],
            }
        },
        geocoder_reverse => {
            buckinghamshire => 'OSPlaces',
        },
        borough_email_addresses => {
            buckinghamshire => {
                districts_flytipping => [
                    { email => "flytipping\@chiltern", areas => [ 2257 ] },
                ]
            }
        }
    }
}, sub {

subtest 'cobrand displays council name' => sub {
    ok $mech->host("buckinghamshire.fixmystreet.com"), "change host to bucks";
    $mech->get_ok('/');
    $mech->content_contains('Buckinghamshire');
};

subtest 'cobrand displays correct categories' => sub {
    my $json = $mech->get_ok_json('/report/new/ajax?latitude=51.615559&longitude=-0.556903');
    is @{$json->{bodies}}, 2, 'Bucks and parish returned';
    like $json->{category}, qr/Car Parks/, 'Car Parks displayed';
    like $json->{category}, qr/Flytipping/, 'Flytipping displayed';
    like $json->{category}, qr/Blocked drain/, 'Blocked drain displayed';
    like $json->{category}, qr/Graffiti/, 'Graffiti displayed';
    like $json->{category}, qr/Grass cutting/, 'Grass cutting displayed';
    unlike $json->{category}, qr/Flytipping \(off-road\)/, 'Flytipping (off-road) not displayed';
    $json = $mech->get_ok_json('/report/new/category_extras?latitude=51.615559&longitude=-0.556903');
    is @{$json->{bodies}}, 2, 'Still Bucks and parish returned';
};

subtest 'parish alert signup' => sub {
    $mech->get_ok('/alert/list?latitude=51.615559&longitude=-0.556903');
    $mech->content_contains('Buckinghamshire Council');
    $mech->content_contains('Chiltern District Council');
    $mech->content_contains('All reports within Adstock parish');
    $mech->content_contains('Only reports sent to Adstock Parish Council');
    $mech->submit_form_ok({ with_fields => {
        feed => 'area:53822',
    } });
};

subtest 'privacy page contains link to Bucks privacy policy' => sub {
    $mech->get_ok('/about/privacy');
    $mech->content_contains('privacy-and-buckinghamshire-highways');
};

my ($report) = $mech->create_problems_for_body(1, $body->id, 'On Road', {
    category => 'Flytipping', cobrand => 'fixmystreet',
    latitude => 51.812244, longitude => -0.827363,
    dt => DateTime->now()->subtract(minutes => 10),
});

subtest 'flytipping on road sent to extra email' => sub {
    FixMyStreet::Script::Reports::send();
    my @email = $mech->get_email;
    is $email[0]->header('To'), 'TfB <flytipping@example.com>';
    is $email[0]->header('Reply-To'), undef, 'No reply-to header';
    like $mech->get_text_body_from_email($email[1]), qr/report's reference number/;
    $report->discard_changes;
    is $report->external_id, 248, 'Report has right external ID';
};

    ($report) = $mech->create_problems_for_body(1, $body->id, 'On Road', {
    category => 'Flytipping', cobrand => 'fixmystreet',
    latitude => 51.812244, longitude => -0.827363,
    extra => {
        contributed_as => 'anonymous_user',
        contributed_by => $counciluser->id,
    },
    dt => DateTime->now()->subtract(minutes => 10),
});

subtest 'report made by council on behalf of anonymous user doesn\'t give staff name/email' => sub {
    $mech->clear_emails_ok;
    FixMyStreet::Script::Reports::send();
    my @email = $mech->get_email;
    is $email[0]->header('To'), 'TfB <flytipping@example.com>';
    is $email[0]->header('Reply-To'), undef, 'No reply-to header';
    like $mech->get_text_body_from_email($email[0]), qr/Reported anonymously/;
    $report->delete;
};

($report) = $mech->create_problems_for_body(1, $body->id, 'On Road', {
    category => 'Potholes', cobrand => 'fixmystreet',
    latitude => 51.812244, longitude => -0.827363,
    extra => {
        contributed_as => 'another_user',
        contributed_by => $counciluser->id,
    },
    dt => DateTime->now()->subtract(minutes => 9),
});

subtest 'pothole on road not sent to extra email, only Open311 sent' => sub {
    $mech->clear_emails_ok;
    FixMyStreet::Script::Reports::send();
    $mech->email_count_is(1);
    like $mech->get_text_body_from_email, qr/report's reference number/;
    $report->discard_changes;
    is $report->get_extra_field_value("asset_resource_id"), "62d6e394942fae016cae1124", "correct asset found";
    is $report->external_id, 248, 'Report has right external ID';
};

# report made in Flytipping category off road should get moved to other category
subtest 'Flytipping not on a road gets recategorised' => sub {
    $mech->log_in_ok($publicuser->email);
    $mech->get_ok('/report/new?latitude=51.615559&longitude=-0.556903&category=Flytipping');
    $mech->submit_form_ok({
        with_fields => {
            title => "Test Report",
            detail => 'Test report details.',
            category => 'Flytipping',
            'road-placement' => 'off-road',
        }
    }, "submit details");
    $mech->content_contains('Your issue is on its way to the council.');
    my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
    ok $report, "Found the report";
    is $report->category, "Flytipping (off-road)", 'Report was recategorised correctly';
};

subtest 'Flytipping not on a road on .com gets recategorised' => sub {
    ok $mech->host("www.fixmystreet.com"), "change host to www";
    $mech->get_ok('/report/new?latitude=51.615559&longitude=-0.556903&category=Flytipping');
    $mech->submit_form_ok({
        with_fields => {
            title => "Test Report",
            detail => 'Test report details.',
            category => 'Flytipping',
            'road-placement' => 'off-road',
        }
    }, "submit details");
    $mech->content_contains('on its way to the council right now');
    $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
    ok $report, "Found the report";
    is $report->category, "Flytipping (off-road)", 'Report was recategorised correctly';
    ok $mech->host("buckinghamshire.fixmystreet.com"), "change host to bucks";
};

subtest 'Can triage an on-road flytipping to off-road' => sub {
    $mech->log_in_ok( $counciluser->email );
    $report->update({ state => 'for triage' });
    $mech->get_ok('/admin/triage');
    $mech->content_contains('Test Report');
    $mech->get_ok('/report/' . $report->id);
    $mech->content_like(qr/<option value="\d+"[^>]*>Flytipping \(off-road\)/);
    $report->update({ state => 'confirmed' });
};

subtest 'Flytipping not on a road going to HE does not get recategorised' => sub {
    $mech->get_ok('/report/new?latitude=51.615559&longitude=-0.556903&category=Flytipping');
    $mech->submit_form_ok({
        with_fields => {
            single_body_only => 'National Highways',
            title => "Test Report",
            detail => 'Test report details.',
            category => 'Flytipping',
            'road-placement' => 'off-road',
        }
    }, "submit details");
    $mech->content_contains('From the information you have given, we have passed this report on to:');
    my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
    ok $report, "Found the report";
    is $report->category, "Flytipping", 'Report was not recategorised';

    $mech->log_out_ok;
};

subtest 'Ex-district reports are sent to correct emails' => sub {
    FixMyStreet::Script::Reports::send();
    $mech->email_count_is(4); # (one for council, one confirmation for user) x 2
    my @email = $mech->get_email;
    is $email[0]->header('To'), '"Buckinghamshire Council" <flytipping@chiltern>';
    unlike $mech->get_text_body_from_email($email[0]), qr/If there is a/;

    like $mech->get_text_body_from_email($email[1]), qr/reference number is/;
    unlike $mech->get_text_body_from_email($email[1]), qr/please contact Buckinghamshire/;
};

my ($report2) = $mech->create_problems_for_body(1, $body->id, 'Drainage problem', {
    category => 'Blocked drain', cobrand => 'fixmystreet',
    latitude => 51.812244, longitude => -0.827363,
    dt => DateTime->now()->subtract(minutes => 8),
});

subtest 'blocked drain sent to extra email' => sub {
    $mech->clear_emails_ok;
    FixMyStreet::Script::Reports::send();
    my @email = $mech->get_email;
    is $email[0]->header('To'), '"Flood Management" <floods@example.org>';
    like $mech->get_text_body_from_email($email[1]), qr/report's reference number/;
};

my $cobrand = FixMyStreet::Cobrand::Buckinghamshire->new();

for my $test (
    {
        desc => 'filters basic emails',
        in => 'email: test@example.com',
        out => 'email: ',
    },
    {
        desc => 'filters emails in brackets',
        in => 'email: <test@example.com>',
        out => 'email: <>',
    },
    {
        desc => 'filters emails from hosts',
        in => 'email: test@mail.example.com',
        out => 'email: ',
    },
    {
        desc => 'filters multiple emails',
        in => 'email: test@example.com and user@fixmystreet.com',
        out => 'email:  and ',
    },
    {
        desc => 'filters basic phone numbers',
        in => 'number: 07700 900000',
        out => 'number: ',
    },
    {
        desc => 'filters multiple phone numbers',
        in => 'number: 07700 900000 and 07700 900001',
        out => 'number:  and ',
    },
    {
        desc => 'filters 3 part phone numbers',
        in => 'number: 0114 496 0999',
        out => 'number: ',
    },
    {
        desc => 'filters international phone numbers',
        in => 'number: +44 114 496 0999',
        out => 'number: ',
    },
    {
        desc => 'filters 020 phone numbers',
        in => 'number: 020 7946 0999',
        out => 'number: ',
    },
    {
        desc => 'filters no area phone numbers',
        in => 'number: 01632 01632',
        out => 'number: ',
    },
    {
        desc => 'does not filter normal numbers',
        in => 'number: 16320163236',
        out => 'number: 16320163236',
    },
    {
        desc => 'does not filter short numbers',
        in => 'number: 0163 1632',
        out => 'number: 0163 1632',
    },
) {
    subtest $test->{desc} => sub {
        is $cobrand->filter_report_description($test->{in}), $test->{out}, "filtered correctly";
    };
}

subtest 'extra CSV columns are present' => sub {
    $mech->log_in_ok( $counciluser->email );

    $mech->get_ok('/dashboard?export=1');

    my @rows = $mech->content_as_csv;
    is scalar @rows, 6, '1 (header) + 4 (reports) = 6 lines';
    is scalar @{$rows[0]}, 22, '22 columns present';

    is_deeply $rows[0],
        [
            'Report ID', 'Title', 'Detail', 'User Name', 'Category',
            'Created', 'Confirmed', 'Acknowledged', 'Fixed', 'Closed',
            'Status', 'Latitude', 'Longitude', 'Query', 'Ward',
            'Easting', 'Northing', 'Report URL', 'Device Type', 'Site Used',
            'Reported As', 'Staff User',
        ],
        'Column headers look correct';

    is $rows[1]->[21], '', 'Staff User is empty if not made on behalf of another user';
    is $rows[2]->[21], $counciluser->email, 'Staff User is correct if made on behalf of another user';
    is $rows[3]->[21], '', 'Staff User is empty if not made on behalf of another user';

    $mech->create_comment_for_problem($report, $counciluser, 'Staff User', 'Some update text', 'f', 'confirmed', undef, {
        extra => { contributed_as => 'body', contributed_by => $counciluser->id }});
    $mech->create_comment_for_problem($report, $counciluser, 'Other User', 'Some update text', 'f', 'confirmed', undef, {
        extra => { contributed_as => 'another_user', contributed_by => $counciluser->id }});

    $mech->get_ok('/dashboard?export=1&updates=1');

    @rows = $mech->content_as_csv;
    is scalar @rows, 3, '1 (header) + 2 (updates)';
    is scalar @{$rows[0]}, 9, '9 columns present';
    is_deeply $rows[0],
        [
            'Report ID', 'Update ID', 'Date', 'Status', 'Problem state',
            'Text', 'User Name', 'Reported As', 'Staff User',
        ],
        'Column headers look correct';

    is $rows[1]->[8], $counciluser->email, 'Staff User is correct if made on behalf of body';
    is $rows[2]->[8], $counciluser->email, 'Staff User is correct if made on behalf of another user';
};

my $bucks = Test::MockModule->new('FixMyStreet::Cobrand::Buckinghamshire');

subtest 'Prevents car park reports being made outside a car park' => sub {
    # Simulate no car parks found
    $bucks->mock('_post', sub { "<wfs:FeatureCollection></wfs:FeatureCollection>" });

    $mech->get_ok('/report/new?latitude=51.615559&longitude=-0.556903&category=Barrier+problem');
    $mech->submit_form_ok({
        with_fields => {
            title => "Test Report",
            detail => 'Test report details.',
            category => 'Barrier problem',
        }
    }, "submit details");
    $mech->content_contains('Please select a location in a Buckinghamshire maintained car park') or diag $mech->content;
};

subtest 'Allows car park reports to be made in a car park' => sub {
    # Now simulate a car park being found
    $bucks->mock('_post', sub {
        "<wfs:FeatureCollection>
            <gml:featureMember>
                <Transport_BC_Car_Parks:BC_CAR_PARKS>
                    <Transport_BC_Car_Parks:OBJECTID>1</Transport_BC_Car_Parks:OBJECTID>
                </Transport_BC_Car_Parks:BC_CAR_PARKS>
            </gml:featureMember>
        </wfs:FeatureCollection>"
    });

    $mech->get_ok('/report/new?latitude=51.615559&longitude=-0.556903&category=Barrier+problem');
    $mech->submit_form_ok({
        with_fields => {
            title => "Test Report",
            detail => 'Test report details.',
            category => 'Barrier problem',
        }
    }, "submit details");
    $mech->content_contains('Your issue is on its way to the council');
};

$report = undef;
subtest 'sends grass cutting reports on roads under 30mph to the parish' => sub {
    FixMyStreet::Script::Reports::send();
    $mech->clear_emails_ok;
    $mech->get_ok('/report/new?latitude=51.615559&longitude=-0.556903&category=Grass+cutting');
    $mech->submit_form_ok({
        with_fields => {
            title => "Test grass cutting report 1",
            detail => 'Test report details.',
            category => 'Grass cutting',
            speed_limit_greater_than_30 => 'no', # Is the speed limit greater than 30mph?
        }
    }, "submit details");
    $mech->content_contains('Your issue is on its way to the council');
    $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
    ok $report, "Found the report";
    is $report->title, 'Test grass cutting report 1', 'Got the correct report';
    is $report->bodies_str, $parish->id, 'Report was sent to parish';
    FixMyStreet::Script::Reports::send();
    my @email = $mech->get_email;
    like $mech->get_text_body_from_email($email[1]), qr/please contact Adstock Parish Council at grassparish\@example.org/;
};

subtest 'Can triage parish reports' => sub {
    $mech->log_in_ok( $counciluser->email );
    $report->update({ state => 'for triage' });
    $mech->get_ok('/admin/triage');
    $mech->content_contains('Test grass cutting report 1');
    $mech->get_ok('/report/' . $report->id);
    $mech->content_contains('Grass cutting (grass@example.org)');
    $mech->content_contains('Grass cutting (grassparish@example.org)');
    $mech->submit_form_ok({ with_fields => { category => $grass_bucks->id } });
    $report->update({ whensent => \'current_timestamp', send_state => 'sent' });
};

subtest '.com reports get the logged email too' => sub {
    ok $mech->host("www.fixmystreet.com"), "change host to www";
    $mech->clear_emails_ok;
    $mech->get_ok('/report/new?latitude=51.615559&longitude=-0.556903&category=Grass+cutting');
    $mech->submit_form_ok({
        with_fields => {
            title => "Test grass cutting report 1b",
            detail => 'Test report details.',
            category => 'Grass cutting',
            speed_limit_greater_than_30 => 'no', # Is the speed limit greater than 30mph?
        }
    }, "submit details");
    $mech->content_contains('Thank you for reporting');
    my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
    ok $report, "Found the report";
    is $report->title, 'Test grass cutting report 1b', 'Got the correct report';
    is $report->bodies_str, $parish->id, 'Report was sent to parish';
    FixMyStreet::Script::Reports::send();
    my @email = $mech->get_email;
    $mech->email_count_is(2);
    like $mech->get_text_body_from_email($email[1]), qr/please contact Adstock Parish Council at grassparish\@example.org/;
    ok $mech->host("buckinghamshire.fixmystreet.com"), "change host to bucks";
};

subtest 'sends grass cutting reports on roads 30mph or more to the council' => sub {
    $mech->get_ok('/report/new?latitude=51.615559&longitude=-0.556903&category=Grass+cutting');
    $mech->submit_form_ok({
        with_fields => {
            title => "Test grass cutting report 2",
            detail => 'Test report details.',
            category => 'Grass cutting',
            speed_limit_greater_than_30 => 'yes', # Is the speed limit greater than 30mph?
        }
    }, "submit details");
    $mech->content_contains('Your issue is on its way to the council');
    my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
    ok $report, "Found the report";
    is $report->title, 'Test grass cutting report 2', 'Got the correct report';
    is $report->bodies_str, $body->id, 'Report was sent to council';
};

subtest "server side speed limit lookup for council grass cutting report" => sub {
    $bucks->mock('_post', sub { "<OS_Highways_Speed:speed>60.00000000</OS_Highways_Speed:speed>" });

    $mech->get_ok('/report/new?latitude=51.615559&longitude=-0.556903&category=Grass+cutting');
    $mech->submit_form_ok({
        with_fields => {
            title => "Test grass cutting report 3",
            detail => 'Test report details.',
            category => 'Grass cutting',
            speed_limit_greater_than_30 => '',
        }
    }, "submit details");
    $mech->content_contains('Your issue is on its way to the council') or diag $mech->content;
    my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
    ok $report, "Found the report";
    is $report->title, 'Test grass cutting report 3', 'Got the correct report';
    is $report->bodies_str, $body->id, 'Report was sent to council';
};

subtest "server side speed limit lookup for parish grass cutting report" => sub {
    $bucks->mock('_post', sub { "<OS_Highways_Speed:speed>30.00000000</OS_Highways_Speed:speed>" });

    $mech->get_ok('/report/new?latitude=51.615559&longitude=-0.556903&category=Grass+cutting');
    $mech->submit_form_ok({
        with_fields => {
            title => "Test grass cutting report 4",
            detail => 'Test report details.',
            category => 'Grass cutting',
        }
    }, "submit details");
    $mech->content_contains('Your issue is on its way to the council');
    my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
    ok $report, "Found the report";
    is $report->title, 'Test grass cutting report 4', 'Got the correct report';
    is $report->bodies_str, $parish->id, 'Report was sent to parish';
};

subtest "server side speed limit lookup with unknown speed limit" => sub {
    $bucks->mock('_post', sub { '' });

    $mech->get_ok('/report/new?latitude=51.615559&longitude=-0.556903&category=Grass+cutting');
    $mech->submit_form_ok({
        with_fields => {
            title => "Test grass cutting report 5",
            detail => 'Test report details.',
            category => 'Grass cutting',
        }
    }, "submit details");
    $mech->content_contains('Your issue is on its way to the council');
    my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
    ok $report, "Found the report";
    is $report->title, 'Test grass cutting report 5', 'Got the correct report';
    is $report->bodies_str, $body->id, 'Report was sent to council';
};

subtest 'treats problems sent to parishes as owned by Bucks' => sub {
    $mech->get_ok('/report/new?latitude=51.615559&longitude=-0.556903');
    $mech->submit_form_ok({
        with_fields => {
            title => "Test Dirty signs report",
            detail => 'Test report details.',
            category => 'Dirty signs',
        }
    }, "submit details");
    $mech->content_contains('Your issue is on its way to the council');

    my $report = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
    ok $report, "Found the report";
    is $report->title, 'Test Dirty signs report', 'Got the correct report';

    $mech->create_comment_for_problem($report, $publicuser, 'Public User', 'Some update text', 'f', 'confirmed');

    # Check that the report can be accessed via the cobrand
    my $report_id = $report->id;
    $mech->get_ok("/report/$report_id");
    $mech->content_contains('Some update text');

    subtest 'Internal referral reports are seen in duplicates' => sub {
        $report->update({ state => 'internal referral' });
        my $json = $mech->get_ok_json( "/around/nearby?filter_category=Dirty+signs&latitude=51.615559&longitude=-0.556903" );
        like $json->{reports_list}, qr/Test Dirty signs report/;
    };
};

subtest 'sending of updates and address' => sub {
    FixMyStreet::Script::Reports::send(); # Clear out any left above
    my ($report1) = $mech->create_problems_for_body(1, $body->id, 'Title update', {
        cobrand => 'buckinghamshire',
        category => 'Abandoned vehicles' });

    my $geocode = Test::MockModule->new('FixMyStreet::Geocode::OSPlaces');
    $geocode->mock(reverse_geocode => sub { { LPI => {
        "ADDRESS" => "STUDIO 1, 29, BUCKINGHAM ROAD, LONDON, BRENT, NW10 4RP",
        "SAO_TEXT" => "STUDIO 1",
        "PAO_START_NUMBER" => "29",
        "STREET_DESCRIPTION" => "BUCKINGHAM ROAD",
        "TOWN_NAME" => "LONDON",
        "ADMINISTRATIVE_AREA" => "BRENT",
        "POSTCODE_LOCATOR" => "NW10 4RP",
    } } });
    FixMyStreet::Script::Reports::send();
    my $req = Open311->test_req_used;
    my $c = CGI::Simple->new($req->content);
    is $c->param('attribute[closest_address]'), "Studio 1\r\n29 Buckingham Road\r\n\r\nLondon\r\nNW10 4RP";

    my ($report2) = $mech->create_problems_for_body(1, $body->id, 'Title update', {
        cobrand => 'buckinghamshire',
        category => 'Potholes' });
    my $update1 = $mech->create_comment_for_problem($report1, $counciluser, 'Staff User', 'Text', 't', 'confirmed', undef);
    my $update2 = $mech->create_comment_for_problem($report2, $counciluser, 'Staff User', 'Text', 't', 'confirmed', undef);
    is $cobrand->should_skip_sending_update($update1), 0;
    is $cobrand->should_skip_sending_update($update2), 1;
};

subtest 'body filter on dashboard' => sub {
    $mech->get_ok('/dashboard');
    $mech->content_contains('<h1>' . $body->name . '</h1>', 'defaults to Bucks');
    $mech->content_contains('<select class="form-control" name="body" id="body">', 'extra bodies dropdown is shown');
    $mech->content_contains('<option value="' . $body->id . '">' . $body->name . '</option>', 'Bucks is shown in the options');
    $mech->content_contains('<option value="' . $parish->id . '">' . $parish->name . '</option>', 'parish is shown in the options');

    $mech->get_ok('/dashboard?body=' . $parish->id);
    $mech->content_contains('<h1>' . $parish->name . '</h1>', 'shows parish dashboard');

    $mech->get_ok('/dashboard?body=' . $other_body->id);
    $mech->content_contains('<h1>' . $body->name . '</h1>', 'defaults to Bucks when body is not permitted');
};

subtest 'All reports pages for parishes' => sub {
    $mech->get_ok('/reports/Buckinghamshire');
    $mech->content_contains('View reports sent to Parish/Town Councils');

    $mech->get_ok('/about/parishes');
    $mech->content_contains('Adstock Parish Council');

    $mech->get_ok('/reports/Adstock');
    $mech->content_contains('Adstock Parish Council');
    is $mech->uri->path, '/reports/Adstock';

    $mech->get_ok('/reports/Aylesbury');
    $mech->content_contains('Aylesbury Town Council');
    is $mech->uri->path, '/reports/Aylesbury';
};

subtest "Only the contact with prefer_if_multiple is returned for the Flyposting category" => sub {
    my $json = $mech->get_ok_json('/report/new/ajax?latitude=51.615559&longitude=-0.556903');
    is scalar @{$json->{by_category}->{'Flyposting'}->{bodies}}, 1, "Only one contact returned";
    is $json->{by_category}->{'Flyposting'}->{bodies}->[0], 'Adstock Parish Council', "Correct contact returned";
};

subtest 'phone number field only appears for staff' => sub {
    $mech->log_out_ok;
    $mech->get_ok('/report/new?latitude=51.615559&longitude=-0.556903');
    $mech->content_lacks("Phone number (optional)");
    $mech->log_in_ok($counciluser->email);
    $mech->get_ok('/report/new?latitude=51.615559&longitude=-0.556903');
    $mech->content_contains("Phone number");
    $mech->log_out_ok;
};

subtest 'Check old confirm reference' => sub {
    my $ref = '40123456';
    $report->set_extra_metadata( confirm_reference => $ref );
    $report->update;

    $mech->get_ok('/');
    $mech->submit_form_ok( { with_fields => { pc => $ref } }, 'Confirm ref');
    is $mech->uri->path, "/report/" . $report->id, "redirected to report page when using Confirm ref";
};

subtest 'Check template setting' => sub {
    $mech->log_in_ok($counciluser->email);
    subtest 'Can set a template with state + external status code' => sub {
        $mech->get_ok( "/admin/templates/" . $body->id . "/new" );
        my $fields = {
            title => "Email 9001 reply",
            text => "Thank you for your report.",
            auto_response => 'on',
            state => 'not responsible',
            external_status_code => 9001,
        };
        $mech->submit_form_ok( { with_fields => $fields } );
        is $mech->uri->path, '/admin/templates/' . $body->id, 'redirected';
        is $body->response_templates->count, 1, "Duplicate response template was added";
    };
    subtest 'Cannot set one with same state + external status code' => sub {
        $mech->get_ok( "/admin/templates/" . $body->id . "/new" );
        my $fields = {
            title => "Email 9001 other reply",
            text => "Thank you for your report.",
            auto_response => 'on',
            state => 'not responsible',
            external_status_code => 9001,
        };
        $mech->submit_form_ok( { with_fields => $fields } );
        is $mech->uri->path, '/admin/templates/' . $body->id . '/new', 'not redirected';
        $mech->content_contains( 'Please correct the errors below' );
        $mech->content_contains( 'There is already an auto-response template for this category/state.' );
        is $body->response_templates->count, 1, "Duplicate response template wasn't added";
    };
    subtest 'Cannot set one with different state + same external status code' => sub {
        $mech->get_ok( "/admin/templates/" . $body->id . "/new" );
        my $fields = {
            title => "Email 9001 fixed reply",
            text => "Thank you for your report.",
            auto_response => 'on',
            state => 'fixed - council',
            external_status_code => 9001,
        };
        $mech->submit_form_ok( { with_fields => $fields } );
        is $mech->uri->path, '/admin/templates/' . $body->id . '/new', 'not redirected';
        $mech->content_contains( 'Please correct the errors below' );
        $mech->content_contains( 'There is already an auto-response template for this category/state.' );
        is $body->response_templates->count, 1, "Duplicate response template wasn't added";
    };
    subtest 'Can set one with same state + different external status code' => sub {
        $mech->get_ok( "/admin/templates/" . $body->id . "/new" );
        my $fields = {
            title => "Email 9002 reply",
            text => "Thank you for your report.",
            auto_response => 'on',
            state => 'not responsible',
            external_status_code => 9002,
        };
        $mech->submit_form_ok( { with_fields => $fields } );
        is $mech->uri->path, '/admin/templates/' . $body->id, 'redirected';
        is $body->response_templates->count, 2, "Duplicate response template was added";
    };
};

subtest 'Littering From Vehicles report' => sub {
    my $contact_lfv = $mech->create_contact_ok(
        body_id     => $body->id,
        category    => 'Littering From Vehicles',
        email       => 'vehicle_littering@example.org',
        send_method => 'Email',
        non_public  => 1,
    );
    my $tmpl_lfv = $body->response_templates->create(
        {   title         => 'Littering From Vehicles Template',
            text          => 'Thank you; we are investigating this.',
            state         => 'confirmed',
            auto_response => 1,
        }
    );
    $tmpl_lfv->add_to_contacts($contact_lfv);

    $mech->log_in_ok( $publicuser->email );

    $mech->get_ok('/report/new?latitude=51.615559&longitude=-0.556903');
    $mech->submit_form_ok(
        {   with_fields => {
                title    => 'Bad Volvo',
                detail   => 'Spewing litter everywhere',
                category => 'Littering From Vehicles',
            },
        },
    );

    my $report
        = FixMyStreet::DB->resultset("Problem")->order_by('-id')->first;
    is $report->category, 'Littering From Vehicles', 'correct category';
    is $report->state,    'confirmed',               'correct initial state';
    is $report->comments, 1, 'initial comment created';
    my $comment = $report->comments->first;
    is $comment->text,          'Thank you; we are investigating this.';
    is $comment->state,         'unconfirmed';
    is $comment->problem_state, 'confirmed';

    FixMyStreet::Script::Reports::send();
    $report->discard_changes;

    is $report->state,    'investigating', 'state changed to investigating';
    is $report->comments, 1,               'no more comments added';
    $comment = $report->comments->first;
    is $comment->state, 'confirmed', 'comment now confirmed';
};

subtest 'Rights of way server fallback' => sub {
    my ($report) = $mech->create_problems_for_body(1, $body->id, 'Title', {
        cobrand => 'buckinghamshire',
        category => 'Rights of way' });
    FixMyStreet::Script::Reports::send();
    $report->discard_changes;
    is $report->get_extra_field_value('LinkCode'), 'AAB/1/1';
};

};

done_testing();
