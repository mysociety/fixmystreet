use strict;
use warnings;
use Test::More;

use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

# check that the homepage loads
$mech->get_ok('/');

subtest "check that the form goes to /around" => sub {
    $mech->get_ok('/');
    is $mech->uri->path, '/', "still on '/'";

    # submit form
    $mech->submit_form_ok( { with_fields => { pc => 'SW1A 1AA', } } );

    # check that we are at /around
    is $mech->uri->path, '/around', "Got to /around";
    is_deeply { $mech->uri->query_form }, { pc => 'SW1A 1AA' },
      "query passed along";
};

subtest "does pc, (x,y), (e,n) or (lat,lon) go to /around" => sub {

    foreach my $test (    #
        {
            in  => { pc => 'SW1A 1AA' },
            out => { pc => 'SW1A 1AA' },
        },
        {
            in  => { lat => 51.50100, lon => -0.14158 },
            out => { lat => 51.50100, lon => -0.14158, zoom => 3 },
        },
        {
            in  => { x   => 3281,      y   => 1113, },
            out => { lat => 51.499825, lon => -0.140137, zoom => 3 },
        },
        {
            in  => { e   => 1234,      n   => 4567 },
            out => { lat => 49.808509, lon => -7.544784, zoom => 3 },
        },
      )
    {

        my $uri = URI->new('http://localhost/');
        $uri->query_form( $test->{in} );

        # get the uri and check for 302
        FixMyStreet::override_config {
            MAPIT_URL => 'http://mapit.mysociety.org/',
        }, sub {
            $mech->get_ok($uri);
        };

        # check that we are at /around
        is $mech->uri->path, '/around', "Got to /around";
        is_deeply { $mech->uri->query_form }, $test->{out}, "query correct";
    }
};

$mech->delete_problems_for_body( 2651 );

my $problem_rs = FixMyStreet::App->model('DB::Problem');
my $num = $problem_rs->count;

my @edinburgh_problems = $mech->create_problems_for_body(5, 2651, 'Front page');
is scalar @edinburgh_problems, 5, 'correct number of edinburgh problems created';

$mech->get_ok('/report/' . $edinburgh_problems[2]->id);
$mech->content_contains('Front page Test 3 for 2651', 'problem to be marked non public visible');
is $problem_rs->count, $num+5;

my $private = $edinburgh_problems[2];
ok $private->update( { non_public => 1 } ), 'problem marked non public';

ok $mech->get('/report/' . $edinburgh_problems[2]->id);
is $mech->res->code, 403, 'page forbidden';
is $problem_rs->count, $num+5;

done_testing();
