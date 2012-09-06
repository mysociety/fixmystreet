use strict;
use warnings;
use Test::More;
use FixMyStreet::TestMech;
use mySociety::MaPit;
use FixMyStreet::App;
use DateTime;

ok( my $mech = FixMyStreet::TestMech->new, 'Created mech object' );

$mech->delete_problems_for_council( 2504 );
$mech->delete_problems_for_council( 2651 );

my @edinburgh_problems = $mech->create_problems_for_council(3, 2651, 'All reports');
my @westminster_problems = $mech->create_problems_for_council(5, 2504, 'All reports');

is scalar @westminster_problems, 5, 'correct number of westminster problems created';
is scalar @edinburgh_problems, 3, 'correct number of edinburgh problems created';

# Run the cron script that makes the data for /reports so we don't get an error.
system( "bin/cron-wrapper update-all-reports" );

# check that we can get the page
$mech->get_ok('/reports');
$mech->title_like(qr{Summary reports});
$mech->content_contains('Birmingham');

my $stats = $mech->extract_report_stats;

is $stats->{'City of Edinburgh Council'}->[1], 3, 'correct number of reports for Edinburgh';
is $stats->{'Westminster City Council'}->[1], 5, 'correct number of reports for Westminster';

$mech->follow_link_ok( { text_regex => qr/Birmingham/ } );

$mech->get_ok('/reports/Westminster');
$mech->title_like(qr/Westminster City Council/);
$mech->content_contains('Westminster City Council');
$mech->content_contains('All reports Test 3 for 2504', 'problem to be marked non public visible');

my $problems = $mech->extract_problem_list;
is scalar @$problems, 5, 'correct number of problems displayed';

my $private = $westminster_problems[2];
ok $private->update( { non_public => 1 } ), 'problem marked non public';

$mech->get_ok('/reports/Westminster');
$problems = $mech->extract_problem_list;
is scalar @$problems, 4, 'only public problems are displayed';

$mech->content_lacks('All reports Test 3 for 2504', 'non public problem is not visible');

$mech->get_ok('/reports');
$stats = $mech->extract_report_stats;
is $stats->{'Westminster City Council'}->[1], 5, 'non public reports included in stats';

SKIP: {
    skip( "Need 'emptyhomes' in ALLOWED_COBRANDS config", 8 )
        unless FixMyStreet::Cobrand->exists('emptyhomes');
    ok $mech->host("reportemptyhomes.com"), 'change host to reportemptyhomes';
    $mech->get_ok('/reports');
    # EHA lacks one column the others have
    $mech->content_lacks('state unknown');

    skip( "Need 'fiksgatami' in ALLOWED_COBRANDS config", 8 )
        unless FixMyStreet::Cobrand->exists('fiksgatami');
    mySociety::MaPit::configure('http://mapit.nuug.no/');
    ok $mech->host("fiksgatami.no"), 'change host to fiksgatami';
    $mech->get_ok('/reports');
    # There should only be one Oslo
    $mech->content_contains('Oslo');
    $mech->content_unlike(qr{Oslo">Oslo.*Oslo}s);
}

done_testing();

