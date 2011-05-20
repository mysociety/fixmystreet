use strict;
use warnings;

use Test::More;

use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

subtest "check that a bad request produces the right response" => sub {

    my $bad_date = "Invalid dates supplied";
    my $bad_type = "Invalid type supplied";

    my %tests = (
        ''                                                => $bad_date,
        'foo=bar'                                         => $bad_date,
        'type=&start_date=&end_date='                     => $bad_date,
        'type=&start_date=bad&end_date=2000-02-01'        => $bad_date,
        'type=&start_date=2000-01-01&end_date=bad'        => $bad_date,
        'type=&start_date=2000-02-31&end_date=2000-02-01' => $bad_date,
        'type=&start_date=2000-01-01&end_date=2000-02-31' => $bad_date,

        'type=&start_date=2000-01-01&end_date=2000-02-01'    => $bad_type,
        'type=foo&start_date=2000-01-01&end_date=2000-02-01' => $bad_type,
    );

    foreach my $q ( sort keys %tests ) {
        is_deeply                            #
          $mech->get_ok_json("/json?$q"),    #
          { error => $tests{$q} },           #
          "correct error for query '$q'";
    }

};

done_testing();
