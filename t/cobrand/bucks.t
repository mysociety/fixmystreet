use Test::MockModule;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2217, 'Buckinghamshire', {
    send_method => 'Open311', api_key => 'key', endpoint => 'endpoint', jurisdiction => 'fms' });
my $counciluser = $mech->create_user_ok('counciluser@example.com', name => 'Council User', from_body => $body);

$mech->create_contact_ok(body_id => $body->id, category => 'Flytipping', email => "FLY");
$mech->create_contact_ok(body_id => $body->id, category => 'Potholes', email => "POT");
$mech->create_contact_ok(body_id => $body->id, category => 'Blocked drain', email => "DRA");

my $district = $mech->create_body_ok(2257, 'Chiltern');
$mech->create_contact_ok(body_id => $district->id, category => 'Flytipping', email => "flytipping\@chiltern");
$mech->create_contact_ok(body_id => $district->id, category => 'Graffiti', email => "graffiti\@chiltern");

my $cobrand = Test::MockModule->new('FixMyStreet::Cobrand::Buckinghamshire');
$cobrand->mock('lookup_site_code', sub {
    my ($self, $row, $buffer) = @_;
    return "Road ID" if $row->latitude == 51.812244;
});

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'buckinghamshire', 'fixmystreet' ],
    MAPIT_URL => 'http://mapit.uk/',
    STAGING_FLAGS => { send_reports => 1, skip_checks => 0 },
}, sub {

subtest 'cobrand displays council name' => sub {
    ok $mech->host("buckinghamshire.fixmystreet.com"), "change host to bucks";
    $mech->get_ok('/');
    $mech->content_contains('Buckinghamshire');
};

subtest 'cobrand displays correct categories' => sub {
    my $json = $mech->get_ok_json('/report/new/ajax?latitude=51.615559&longitude=-0.556903');
    is @{$json->{bodies}}, 2, 'Both Chiltern and Bucks returned';
    like $json->{category}, qr/Flytipping/, 'Flytipping displayed';
    like $json->{category}, qr/Blocked drain/, 'Blocked drain displayed';
    unlike $json->{category}, qr/Graffiti/, 'Graffiti not displayed';
    $json = $mech->get_ok_json('/report/new/category_extras?latitude=51.615559&longitude=-0.556903');
    is @{$json->{bodies}}, 2, 'Still both Chiltern and Bucks returned';
};

my ($report) = $mech->create_problems_for_body(1, $body->id, 'On Road', {
    category => 'Flytipping', cobrand => 'fixmystreet',
    latitude => 51.812244, longitude => -0.827363,
});

subtest 'flytipping on road sent to extra email' => sub {
    FixMyStreet::Script::Reports::send();
    my @email = $mech->get_email;
    my $tfb = join('', 'illegaldumpingcosts', '@', 'buckscc.gov.uk');
    is $email[0]->header('To'), '"TfB" <' . $tfb . '>';
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
});

subtest 'pothole on road not sent to extra email, only confirm sent' => sub {
    $mech->clear_emails_ok;
    FixMyStreet::Script::Reports::send();
    $mech->email_count_is(1);
    like $mech->get_text_body_from_email, qr/report's reference number/;
    $report->discard_changes;
    is $report->external_id, 248, 'Report has right external ID';
};

($report) = $mech->create_problems_for_body(1, $district->id, 'Off Road', {
    category => 'Flytipping', cobrand => 'buckinghamshire',
    latitude => 51.813173, longitude => -0.826741,
});
subtest 'flytipping off road sent to extra email' => sub {
    FixMyStreet::Script::Reports::send();
    my @email = $mech->get_email;
    is $email[0]->header('To'), '"Chiltern" <flytipping@chiltern>';
    like $mech->get_text_body_from_email($email[1]), qr/Please note that Buckinghamshire County Council is not responsible/;
    $report->discard_changes;
    is $report->external_id, undef, 'Report has right external ID';
};

my ($report2) = $mech->create_problems_for_body(1, $body->id, 'Drainage problem', {
    category => 'Blocked drain', cobrand => 'fixmystreet',
    latitude => 51.812244, longitude => -0.827363,
});

subtest 'blocked drain sent to extra email' => sub {
    $mech->clear_emails_ok;
    FixMyStreet::Script::Reports::send();
    my @email = $mech->get_email;
    my $e = join('@', 'floodmanagement', 'buckscc.gov.uk');
    is $email[0]->header('To'), '"Flood Management" <' . $e . '>';
    like $mech->get_text_body_from_email($email[1]), qr/report's reference number/;
};

$cobrand = FixMyStreet::Cobrand::Buckinghamshire->new();

subtest 'Flytipping extra question used if necessary' => sub {
    my $errors = { 'road-placement' => 'This field is required' };

    $report->update({ bodies_str => $body->id });
    $cobrand->flytipping_body_fix($report, 'road', $errors);
    is $errors->{'road-placement'}, 'This field is required', 'Error stays if sent to county';

    $report->update({ bodies_str => $district->id });
    $report->discard_changes; # As e.g. ->bodies has been remembered.
    $cobrand->flytipping_body_fix($report, 'road', $errors);
    is $errors->{'road-placement'}, undef, 'Error removed if sent to district';

    $report->update({ bodies_str => $body->id . ',' . $district->id });
    $report->discard_changes; # As e.g. ->bodies has been remembered.
    $cobrand->flytipping_body_fix($report, 'road', $errors);
    is $report->bodies_str, $body->id, 'Sent to both becomes sent to county on-road';

    $report->update({ bodies_str => $district->id . ',' . $body->id });
    $report->discard_changes; # As e.g. ->bodies has been remembered.
    $cobrand->flytipping_body_fix($report, 'off-road', $errors);
    is $report->bodies_str, $district->id, 'Sent to both becomes sent to district off-road';
};

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
