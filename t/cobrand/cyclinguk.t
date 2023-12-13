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

$mech->log_in_ok($super->email);

subtest 'cyclinguk dashboard shows correct report data' => sub {
    $problem->update({ cobrand => 'fixmystreet'});
    $mech->get_ok("/dashboard");
    $mech->content_contains("0 opened, 0 closed, 0 fixed", ".com reports not shown in dashboard");

    $problem->update({ cobrand => 'bathnes'});
    $mech->get_ok("/dashboard");
    $mech->content_contains("0 opened, 0 closed, 0 fixed", "council cobrand reports not shown in dashboard");

    $problem->update({ cobrand => 'cyclinguk'});
    $mech->get_ok("/dashboard");
    $mech->content_contains("1 opened, 0 closed, 0 fixed", "cyclinguk cobrand reports are shown in dashboard");
};

subtest 'cyclinguk dashboard shows correct bodies' => sub {
    $mech->get_ok("/dashboard");
    $mech->content_contains("<option value=''>All</option>");
    $mech->content_contains('<option value="' . $body->id . '">Bath and North East Somerset Council</option>');
};

$mech->log_out_ok;

};

done_testing();
