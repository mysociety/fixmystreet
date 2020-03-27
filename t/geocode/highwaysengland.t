use FixMyStreet::Test;
use HighwaysEngland;
use Test::MockModule;

my $he = Test::MockModule->new('HighwaysEngland');
$he->mock('database_file', sub { FixMyStreet->path_to('t/geocode/roads.sqlite'); });


for my $test (
  {
      search => 'M1, Jct 16',
      latitude => 52.2302496115401,
      long => -1.01582565724738,
      desc => 'junction number second'
  },
  {
      search => 'Jct 16, M1',
      latitude => 52.2302496115401,
      long => -1.01582565724738,
      desc => 'junction number first'
  },
  {
      search => 'M1 Jct 16',
      latitude => 52.2302496115401,
      long => -1.01582565724738,
      desc => 'no comma as separator'
  },
  {
      search => 'M1 Jct16',
      latitude => 52.2302496115401,
      long => -1.01582565724738,
      desc => 'no space in junction name'
  },
  {
      search => 'M1 J16',
      latitude => 52.2302496115401,
      long => -1.01582565724738,
      desc => 'J for junction'
  },
  {
      search => 'M1 Junction 16',
      latitude => 52.2302496115401,
      long => -1.01582565724738,
      desc => 'junction as word'
  },
  {
      search => 'm1 j16',
      latitude => 52.2302496115401,
      long => -1.01582565724738,
      desc => 'lower case search'
  },
  {
      search => 'A1, B668',
      latitude => 52.7323808633713,
      long => -0.599568322474905,
      desc => 'road with joining road second'
  },
  {
      search => ' B668, A1',
      latitude => 52.7323808633713,
      long => -0.599568322474905,
      desc => 'road with joining road first'
  },
  {
      search => 'A1, A607',
      latitude => 52.8975982569244,
      long => -0.664016143160206,
      desc => 'road with joining A road'
  },
  {
      search => 'A1, Long Bennington',
      latitude => 52.979716221406,
      long => -0.746100037226323,
      desc => 'road with junction town'
  },
  {
      search => 'Long Bennington, A1',
      latitude => 52.979716221406,
      long => -0.746100037226323,
      desc => 'road with junction town first'
  },
  {
      search => 'A14, J2',
      latitude => 52.3998144608558,
      long => -0.916447519667833,
      desc => 'road with more than one number'
  },
  {
      search => 'Watford gap services',
      latitude => 52.3068680406392,
      long => -1.1219749609866,
      desc => 'motorway services'
  },
  {
      search => 'M1 42.1',
      latitude => 51.7926609391213,
      long => -0.411879446242646,
      desc => 'road and distance'
  },
) {
    subtest $test->{desc} => sub {
      my $r = HighwaysEngland::junction_lookup($test->{search});
      is $r->{latitude}, $test->{latitude}, 'correct latitude';
      is $r->{longtude}, $test->{longtude}, 'correct longtude';
    };
}

done_testing;
