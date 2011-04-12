use strict;
use warnings;
use Test::More;

use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

# check that the homepage loads
$mech->get_ok('/');

subtest "check that the form goes to /around" => sub {
    $mech->get_ok('/');

    # submit form
    $mech->submit_form_ok( { with_fields => { pc => 'SW1A 1AA', } } );

    # check that we are at /around
    is $mech->res->uri->path, '/around', "Got to /around";
    is $mech->res->uri->query_form, { pc => 'SW1A 1AA' }, "query passed along";
};

subtest "check that requests with pc, x,y or lat,lon go to /around" => sub {
    foreach my $test (
        { pc  => 'SW1A 1AA', },
        { x   => 3281, y => 1113, },
        { lat => 51.50100, lon => -0.14158, },
      )
    {
        my $uri = URI->new('http://localhost/');
        $uri->query_form($test);
        $mech->get_ok($uri);

        # check that we are at /around
        is $mech->res->uri->path, '/around', "Got to /around";
        is $mech->res->uri->query_form, $test, "query passed along";
    }
};

done_testing();
