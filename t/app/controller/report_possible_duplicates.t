use strict;
use warnings;
use Test::More;
use FixMyStreet::TestMech;
use mySociety::MaPit;
use FixMyStreet::App;
use DateTime;

use t::Mock::MapIt;

my $mech = FixMyStreet::TestMech->new;

$mech->create_body_ok(2514, 'Birmingham City Council');

my @birmingham_problems = $mech->create_problems_for_body(5, 2514, 'All reports');

$birmingham_problems[0]->update( {
    title => 'Nearby problem 1 - same category',
    state => 'in progress',
    latitude => 52.477662,
    longitude => -1.898012,
    category => 'Potholes',
  }
);

$birmingham_problems[1]->update( {
    title => 'Nearby problem 2 - same category',
    state => 'in progress',
    latitude => 52.477595,
    longitude => -1.897950,
    category => 'Potholes',
  }
);

$birmingham_problems[2]->update( {
    title => 'Fixed problem - same category',
    state => 'fixed - council',
    latitude => 52.477595,
    longitude => -1.897950,
    category => 'Potholes',
  }
);

$birmingham_problems[3]->update( {
    title => 'Nearby problem - different category',
    state => 'in progress',
    latitude => 52.477595,
    longitude => -1.897950,
    category => 'Street cleaning',
  }
);

$birmingham_problems[4]->update( {
    title => 'Same category - nowhere near',
    category => 'Potholes',
  }
);

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ { 'fixmystreet' => '.' } ],
    MAPIT_URL => 'http://mapit.mysociety.org/',
}, sub {
  my $json = $mech->get_ok_json('/report/new/possible_duplicates?latitude=52.477595&longitude=-1.897950&category=Potholes');
  my $count = $json->{count};

  is $count, 2, 'Correct number of reports is returned';

  $mech->content_contains('Nearby problem 1 - same category');
  $mech->content_contains('Nearby problem 2 - same category');
  $mech->content_lacks('Fixed problem - same category');
  $mech->content_lacks('Nearby problem - different category');
  $mech->content_lacks('Same category - nowhere near');
};

done_testing();
