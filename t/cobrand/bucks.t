use Test::MockModule;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;

my $mech = FixMyStreet::TestMech->new;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }

my $body = $mech->create_body_ok(2217, 'Buckinghamshire', {
    send_method => 'Open311', api_key => 'key', endpoint => 'endpoint', jurisdiction => 'fms', can_be_devolved => 1 });
my $counciluser = $mech->create_user_ok('counciluser@example.com', name => 'Council User', from_body => $body);
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
$mech->create_contact_ok(body_id => $body->id, category => 'Potholes', email => "POT");
$mech->create_contact_ok(body_id => $body->id, category => 'Blocked drain', email => "DRA");
$mech->create_contact_ok(body_id => $body->id, category => 'Car Parks', email => "car\@chiltern", send_method => 'Email');
$mech->create_contact_ok(body_id => $body->id, category => 'Graffiti', email => "graffiti\@chiltern", send_method => 'Email');
$mech->create_contact_ok(body_id => $body->id, category => 'Flytipping (off-road)', email => "districts_flytipping", send_method => 'Email');

my $cobrand = Test::MockModule->new('FixMyStreet::Cobrand::Buckinghamshire');
$cobrand->mock('lookup_site_code', sub {
    my ($self, $row) = @_;
    return "Road ID" if $row->latitude == 51.812244;
});

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'buckinghamshire', 'fixmystreet' ],
    MAPIT_URL => 'http://mapit.uk/',
    STAGING_FLAGS => { send_reports => 1, skip_checks => 0 },
    COBRAND_FEATURES => {
        open311_email => {
            buckinghamshire => {
                flytipping => 'flytipping@example.org',
                flood => 'floods@example.org',
            }
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
    is @{$json->{bodies}}, 1, 'Bucks returned';
    like $json->{category}, qr/Car Parks/, 'Car Parks displayed';
    like $json->{category}, qr/Flytipping/, 'Flytipping displayed';
    like $json->{category}, qr/Blocked drain/, 'Blocked drain displayed';
    like $json->{category}, qr/Graffiti/, 'Graffiti displayed';
    unlike $json->{category}, qr/Flytipping \(off-road\)/, 'Flytipping (off-road) not displayed';
    $json = $mech->get_ok_json('/report/new/category_extras?latitude=51.615559&longitude=-0.556903');
    is @{$json->{bodies}}, 1, 'Still Bucks returned';
};

my ($report) = $mech->create_problems_for_body(1, $body->id, 'On Road', {
    category => 'Flytipping', cobrand => 'fixmystreet',
    latitude => 51.812244, longitude => -0.827363,
    dt => DateTime->now()->subtract(minutes => 10),
});

subtest 'flytipping on road sent to extra email' => sub {
    FixMyStreet::Script::Reports::send();
    my @email = $mech->get_email;
    is $email[0]->header('To'), 'TfB <flytipping@example.org>';
    like $mech->get_text_body_from_email($email[1]), qr/report's reference number/;
    $report->discard_changes;
    is $report->external_id, 248, 'Report has right external ID';
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

subtest 'pothole on road not sent to extra email, only confirm sent' => sub {
    $mech->clear_emails_ok;
    FixMyStreet::Script::Reports::send();
    $mech->email_count_is(1);
    like $mech->get_text_body_from_email, qr/report's reference number/;
    $report->discard_changes;
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
    my $report = FixMyStreet::DB->resultset("Problem")->search(undef, { order_by => { -desc => 'id' } })->first;
    ok $report, "Found the report";
    is $report->category, "Flytipping (off-road)", 'Report was recategorised correctly';

    $mech->log_out_ok;
};

subtest 'Ex-district reports are sent to correct emails' => sub {
    FixMyStreet::Script::Reports::send();
    $mech->email_count_is(2); # one for council, one confirmation for user
    my @email = $mech->get_email;
    is $email[0]->header('To'), 'Buckinghamshire <flytipping@chiltern>';
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

$cobrand = FixMyStreet::Cobrand::Buckinghamshire->new();

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
    is scalar @rows, 5, '1 (header) + 4 (reports) = 5 lines';
    is scalar @{$rows[0]}, 21, '21 columns present';

    is_deeply $rows[0],
        [
            'Report ID', 'Title', 'Detail', 'User Name', 'Category',
            'Created', 'Confirmed', 'Acknowledged', 'Fixed', 'Closed',
            'Status', 'Latitude', 'Longitude', 'Query', 'Ward',
            'Easting', 'Northing', 'Report URL', 'Site Used',
            'Reported As', 'Staff User',
        ],
        'Column headers look correct';

    is $rows[1]->[20], '', 'Staff User is empty if not made on behalf of another user';
    is $rows[2]->[20], $counciluser->email, 'Staff User is correct if made on behalf of another user';
    is $rows[3]->[20], '', 'Staff User is empty if not made on behalf of another user';

    $mech->create_comment_for_problem($report, $counciluser, 'Staff User', 'Some update text', 'f', 'confirmed', undef, {
        extra => { contributed_as => 'body' }});
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

    is $rows[1]->[8], '', 'Staff User is empty if not made on behalf of another user';
    is $rows[2]->[8], $counciluser->email, 'Staff User is correct if made on behalf of another user';
};

};

done_testing();
