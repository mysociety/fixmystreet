use Test::MockModule;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2217, 'Buckinghamshire', {
    send_method => 'Open311', api_key => 'key', endpoint => 'endpoint', jurisdiction => 'fms' });

$mech->create_contact_ok(body_id => $body->id, category => 'Flytipping', email => "FLY");
$mech->create_contact_ok(body_id => $body->id, category => 'Potholes', email => "POT");

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
    my $email = $mech->get_email;
    my $tfb = join('', 'illegaldumpingcosts', '@', 'buckscc.gov.uk');
    is $email->header('To'), '"TfB" <' . $tfb . '>';
    $report->discard_changes;
    is $report->external_id, 248, 'Report has right external ID';
};

($report) = $mech->create_problems_for_body(1, $body->id, 'On Road', {
    category => 'Potholes', cobrand => 'fixmystreet',
    latitude => 51.812244, longitude => -0.827363,
});

subtest 'pothole on road not sent to extra email' => sub {
    $mech->clear_emails_ok;
    FixMyStreet::Script::Reports::send();
    $mech->email_count_is(0);
    $report->discard_changes;
    is $report->external_id, 248, 'Report has right external ID';
};

($report) = $mech->create_problems_for_body(1, $district->id, 'Off Road', {
    category => 'Flytipping', cobrand => 'fixmystreet',
    latitude => 51.813173, longitude => -0.826741,
});
subtest 'flytipping off road sent to extra email' => sub {
    FixMyStreet::Script::Reports::send();
    my $email = $mech->get_email;
    is $email->header('To'), '"Chiltern" <flytipping@chiltern>';
    $report->discard_changes;
    is $report->external_id, undef, 'Report has right external ID';
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

};

done_testing();
