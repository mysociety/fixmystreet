use FixMyStreet::TestMech;
use DateTime;

my $mech = FixMyStreet::TestMech->new;

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'hart' ],
}, sub {
    ok $mech->host("hart.fixmystreet.com"), "change host to hart";
    $mech->get_ok('/');
    $mech->content_like( qr/Hart\b/ );
};

my $body =  $mech->create_body_ok(2333, "Hart District Council", { cobrand => 'hart' });
my $staff_user = $mech->create_user_ok('staff@example.com', name => 'Admin', from_body => $body);
my $category = $mech->create_contact_ok( category => "Pothole", body_id => $body->id, email => 'pothole@hart-example.org' );
my $new_problem = $mech->create_problems_for_body( 1, $body->id, 'Around page', {
            postcode  => 'GU51 4AE',
            latitude  => 51.279456,
            longitude => -0.846216,
            category => "Pothole",
    });

my $dt = DateTime->now()->add( months => -7 );
my $old_problem = $mech->create_problems_for_body( 1, $body->id, 'Around page', {
            postcode  => 'GU51 4AE',
            latitude  => 51.279456,
            longitude => -0.846216,
            category => "Pothole",
            created => $dt,
            confirmed => $dt,
    });

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'hart' ],
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    ok $mech->host("hart.fixmystreet.com"), "change host to hart";
    $mech->get_ok('/around?lat=51.279456&lon=-0.846216');
    $mech->content_like( qr{id="show_old_reports_wrapper".*?hidden">\n} );
};

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'hart' ],
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    ok $mech->host("hart.fixmystreet.com"), "change host to hart";
    $mech->log_in_ok($staff_user->email);
    $mech->get_ok('/around?lat=51.279456&lon=-0.846216');
    $mech->content_unlike( qr{id="show_old_reports_wrapper".*?hidden">\n} );
};

done_testing();
