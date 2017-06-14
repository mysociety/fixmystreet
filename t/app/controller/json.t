use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

subtest "check that a bad request produces the appropriate response" => sub {

    my $bad_date = "Invalid dates supplied";
    my $mad_date = "Start date after end date";
    my $bad_type = "Invalid type supplied";

    my %tests = (
        '?'                                                => $bad_date,
        '?foo=bar'                                         => $bad_date,
        '?start_date=&end_date='                     => $bad_date,
        '?start_date=bad&end_date=2000-02-01'        => $bad_date,
        '?start_date=2000-01-01&end_date=bad'        => $bad_date,
        '?start_date=2000-02-31&end_date=2000-02-01' => $bad_date,
        '?start_date=2000-01-01&end_date=2000-02-31' => $bad_date,
          
        '?start_date=2000-02-01&end_date=2000-01-01' => $mad_date,
          
        '?start_date=2000-01-01&end_date=2000-02-01'    => $bad_type,
        '/foo?type=foo&start_date=2000-01-01&end_date=2000-02-01' => $bad_type,
    );

    foreach my $q ( sort keys %tests ) {
        is_deeply                            #
          $mech->get_ok_json("/json/problems$q"),    #
          { error => $tests{$q} },           #
          "correct error for query '$q'";
    }

};

is_deeply                                    #
  $mech->get_ok_json(
    "/json/problems/new?start_date=2000-01-01&end_date=2000-02-01"),    #
  [],                                                                        #
  "correct response";

# put an entry in the database for this test
my $user = $mech->create_user_ok('test@example.com');

my $body = $mech->create_body_ok(2501, 'Wandsworth Borough Council');

my $problem_args = {
    postcode  => 'sw1a 1aa',
    bodies_str => $body->id,
    areas     => ',105164,11806,11827,2247,2501,34817,42011,66045,70786,8519,',
    category  => 'test category',
    title     => 'Test title',
    detail    => 'Test detail',
    used_map  => 't',
    name      => 'Test Name',
    created   => '2000-01-01 12:00:00',
    confirmed => '2000-01-01 12:01:00',
    state     => 'confirmed',
    lang      => 'en-gb',
    service   => '',
    cobrand   => '',
    cobrand_data       => '',
    lastupdate         => '2000-01-01 12:00:00',
    whensent           => undef,
    send_questionnaire => 't',
    latitude           => '51.4531988729771',
    longitude          => '-0.23021896608596',
};
my $problem      = $user->add_to_problems( { %$problem_args, anonymous => 0 } );
my $anon_problem = $user->add_to_problems( { %$problem_args, anonymous => 1, confirmed => '2000-01-01 12:02:00' } );

ok $problem,      "created normal test problem";
ok $anon_problem, "created anon test problem";

is_deeply    #
  $mech->get_ok_json(
    "/json/problems/new?start_date=2000-01-01&end_date=2000-02-01"),    #
  [
    {
        'state'     => 'confirmed',
        'longitude' => -0.23021896608596,
        'latitude'  => 51.4531988729771,
        'used_map'  => 1,
        'anonymous' => 0,
        'category'  => 'test category',
        'confirmed' => '2000-01-01 12:01:00',
        'lastupdate' => '2000-01-01 12:00:00',
        'bodies_str' => 'Wandsworth Borough Council',
        'detail'    => 'Test detail',
        'id'        => $problem->id,
        'name'      => 'Test Name',
        'service'   => 'Web interface',
        'title'     => 'Test title',
        'whensent'  => undef
    },
    {
        'state'     => 'confirmed',
        'longitude' => -0.23021896608596,
        'latitude'  => 51.4531988729771,
        'used_map'  => 1,
        'anonymous' => 1,
        'category'  => 'test category',
        'confirmed' => '2000-01-01 12:02:00',
        'lastupdate' => '2000-01-01 12:00:00',
        'bodies_str' => 'Wandsworth Borough Council',
        'detail'    => 'Test detail',
        'id'        => $anon_problem->id,
        'name'      => '',
        'service'   => 'Web interface',
        'title'     => 'Test title',
        'whensent'  => undef
    }
  ],
  "correct response";

done_testing();
