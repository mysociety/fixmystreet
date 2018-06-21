use Test::MockModule;
use FixMyStreet::TestMech;
use FixMyStreet::Script::Reports;

my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2217, 'Buckinghamshire');
$mech->create_contact_ok(body_id => $body->id, category => 'Flytipping', email => "flytipping\@example.org");

my $cobrand = Test::MockModule->new('FixMyStreet::Cobrand::Buckinghamshire');
$cobrand->mock('lookup_site_code', sub {
    my ($self, $row, $buffer) = @_;
    return "Road ID" if $row->latitude == 51.812244;
});

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'buckinghamshire', 'fixmystreet' ],
    MAPIT_URL => 'http://mapit.uk/',
}, sub {

subtest 'cobrand displays council name' => sub {
    ok $mech->host("buckinghamshire.fixmystreet.com"), "change host to bucks";
    $mech->get_ok('/');
    $mech->content_contains('Buckinghamshire');
};

$mech->create_problems_for_body(1, $body->id, 'On Road', {
    category => 'Flytipping', cobrand => 'fixmystreet',
    latitude => 51.812244, longitude => -0.827363,
});

subtest 'flytipping on road sent to extra email' => sub {
    FixMyStreet::Script::Reports::send();
    my $email = $mech->get_email;
    my $tfb = join('', 'internaltfb', '@', 'buckscc.gov.uk');
    is $email->header('To'), '"Buckinghamshire" <flytipping@example.org>, "TfB" <' . $tfb . '>';
};

$mech->create_problems_for_body(1, $body->id, 'Off Road', {
    category => 'Flytipping', cobrand => 'fixmystreet',
    latitude => 51.813173, longitude => -0.826741,
});
subtest 'flytipping on road sent to extra email' => sub {
    $mech->clear_emails_ok;
    FixMyStreet::Script::Reports::send();
    my $email = $mech->get_email;
    is $email->header('To'), '"Buckinghamshire" <flytipping@example.org>';
};

};

done_testing();
