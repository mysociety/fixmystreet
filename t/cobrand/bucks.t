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

};

done_testing();
