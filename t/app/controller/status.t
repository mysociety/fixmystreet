use FixMyStreet::TestMech;
use Test::MockModule;


ok( my $mech = FixMyStreet::TestMech->new, 'Created mech object' );

my $surrey = $mech->create_body_ok(2242, 'Surrey County Council');
(my $report) = $mech->create_problems_for_body(1, $surrey->id, 'Pothole', {
    category => 'Potholes', cobrand => 'surrey',
    latitude => 51.293415, longitude => -0.441269, areas => '2242',
});


subtest 'Health page returns 200 when things are OK' => sub {
    $mech->get_ok('/status/health');
    is $mech->content, 'OK: ' . $report->id, 'Got correct content for status page';
    is $mech->res->code, 200, 'Got 200 for status page';
};

subtest 'Health page returns 500 when things are not OK' => sub {
    my $rs = Test::MockModule->new('FixMyStreet::DB::ResultSet::Problem');
    $rs->mock('first', sub { die 'DB error' });
    $mech->get('/status/health');
    is $mech->res->code, 500, 'Got 500 for status page';
};


done_testing();
