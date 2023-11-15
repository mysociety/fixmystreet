use Test::MockModule;
use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

my $cobrand = Test::MockModule->new('FixMyStreet::Cobrand::BathNES');
$cobrand->mock('area_types', sub { [ 'UTA' ] });

my $body = $mech->create_body_ok(2551, 'Bath and North East Somerset Council', {}, { cobrand => 'bathnes' });
my $cyclinguk = $mech->create_body_ok(2551, 'Cycling UK', {}, { cobrand => 'cyclinguk' });
$cyclinguk->body_areas->delete;

my $contact = $mech->create_contact_ok(
    body_id => $body->id,
    category => 'Potholes',
    email => 'POTHOLE',
);

my $user = $mech->create_user_ok( 'bathnes@example.com' );
my $staff = $mech->create_user_ok( 'staff@cyclinguk.org' );
my $super = $mech->create_user_ok( 'super@example.com', name => 'Super User', is_superuser => 1 );

my ($problem) = $mech->create_problems_for_body(1, $body->id, 'Title', {
    areas => ",2651,", category => 'Potholes', cobrand => 'fixmystreet',
    user => $user,
});

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'cyclinguk' ],
    COBRAND_FEATURES => {
        base_url => {
            cyclinguk => "http://cyclinguk.fixmystreet.com/",
        },
    },
    MAPIT_URL => 'http://mapit.uk/',
    STAGING_FLAGS => { skip_must_have_2fa => 1 },
}, sub {

subtest 'cobrand front page looks OK' => sub {
    $mech->get_ok('/');
    $mech->content_contains("Fill That Hole");
    $mech->content_contains("Report or find a hazard");
    $mech->content_lacks("Report, view, or discuss local problems");
};

subtest '.com and council cobrand reports do not appear on site' => sub {
    $problem->update({ cobrand => 'fixmystreet'});
    $mech->get('/report/' . $problem->id);
    is $mech->res->code, 404;
    $mech->get_ok('/reports/Bath+and+North+East+Somerset');
    $mech->content_lacks($problem->title);
    $mech->log_in_ok($super->email);
    $mech->get('/admin/report_edit/' . $problem->id);
    is $mech->res->code, 404;
    $mech->log_out_ok;

    $problem->update({ cobrand => 'bathnes'});
    $mech->get('/report/' . $problem->id);
    is $mech->res->code, 404;
    $mech->get_ok('/reports/Bath+and+North+East+Somerset');
    $mech->content_lacks($problem->title);
    $mech->log_in_ok($super->email);
    $mech->get('/admin/report_edit/' . $problem->id);
    is $mech->res->code, 404;
    $mech->log_out_ok;
};

subtest 'cyclinguk cobrand reports do appear on site' => sub {
    $problem->update({ cobrand => 'cyclinguk'});
    $mech->get_ok('/report/' . $problem->id);
    $mech->content_contains($problem->title);
    $mech->get_ok('/reports/Bath+and+North+East+Somerset');
    $mech->content_contains($problem->title);
};

};


done_testing();
