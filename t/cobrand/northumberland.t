use FixMyStreet::TestMech;
use FixMyStreet::App;

# disable info logs for this test run
FixMyStreet::App->log->disable('info');
END { FixMyStreet::App->log->enable('info'); }


my $mech = FixMyStreet::TestMech->new;

my $body = $mech->create_body_ok(2248, 'Northumberland County Council', {}, { cobrand => 'northumberland' });
$mech->create_problems_for_body(1, $body->id, 'Test', { anonymous => 't' });

my $staffuser = $mech->create_user_ok('counciluser@example.com', name => 'Council User', from_body => $body, password => 'password');

FixMyStreet::override_config {
    ALLOWED_COBRANDS => 'northumberland',
    MAPIT_URL => 'http://mapit.uk/',
}, sub {
    subtest 'Dashboard CSV includes name of publicly anonymous reporter' => sub {
        $mech->log_in_ok( $staffuser->email );
        $mech->get_ok('/dashboard?export=1');
        $mech->content_contains('Test User');
    };
};

done_testing();
