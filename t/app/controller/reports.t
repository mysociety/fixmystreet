use strict;
use warnings;
use Test::More;
use FixMyStreet::TestMech;
use mySociety::MaPit;
use FixMyStreet::App;
use DateTime;

ok( my $mech = FixMyStreet::TestMech->new, 'Created mech object' );

$mech->create_body_ok(2514, 'Birmingham City Council');
$mech->create_body_ok(2651, 'City of Edinburgh Council');
$mech->create_body_ok(2504, 'Westminster City Council');

$mech->delete_problems_for_body( 2504 );
$mech->delete_problems_for_body( 2651 );

my @edinburgh_problems = $mech->create_problems_for_body(3, 2651, 'All reports');
my @westminster_problems = $mech->create_problems_for_body(5, 2504, 'All reports');

is scalar @westminster_problems, 5, 'correct number of westminster problems created';
is scalar @edinburgh_problems, 3, 'correct number of edinburgh problems created';

$edinburgh_problems[1]->update( {
    state => 'in progress',
    confirmed => DateTime->now()->subtract( weeks => 6 ),
    lastupdate => DateTime->now()->subtract( weeks => 5 ),
} );

# Run the cron script that makes the data for /reports so we don't get an error.
system( "bin/cron-wrapper update-all-reports" );

# check that we can get the page
$mech->get_ok('/reports');
$mech->title_like(qr{Summary reports});
$mech->content_contains('Birmingham');

my $stats = $mech->extract_report_stats;

is $stats->{'City of Edinburgh Council'}->[1], 2, 'correct number of new reports for Edinburgh';
is $stats->{'City of Edinburgh Council'}->[2], 1, 'correct number of older reports for Edinburgh';

is $stats->{'Westminster City Council'}->[1], 5, 'correct number of reports for Westminster';

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.mysociety.org/',
}, sub {
    $mech->follow_link_ok( { text_regex => qr/Birmingham/ } );
    $mech->get_ok('/reports/Westminster');
};

$mech->title_like(qr/Westminster City Council/);
$mech->content_contains('Westminster City Council');
$mech->content_contains('All reports Test 3 for 2504', 'problem to be marked non public visible');

my $problems = $mech->extract_problem_list;
is scalar @$problems, 5, 'correct number of problems displayed';

my $private = $westminster_problems[2];
ok $private->update( { non_public => 1 } ), 'problem marked non public';

FixMyStreet::override_config {
    MAPIT_URL => 'http://mapit.mysociety.org/',
}, sub {
    $mech->get_ok('/reports/Westminster');
};
$problems = $mech->extract_problem_list;
is scalar @$problems, 4, 'only public problems are displayed';

$mech->content_lacks('All reports Test 3 for 2504', 'non public problem is not visible');

$mech->get_ok('/reports');
$stats = $mech->extract_report_stats;
is $stats->{'Westminster City Council'}->[1], 5, 'non public reports included in stats';

subtest "test emptyhomes all reports page" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'emptyhomes' ],
    }, sub {
        ok $mech->host("reportemptyhomes.com"), 'change host to reportemptyhomes';
        $mech->get_ok('/reports');
        # EHA lacks one column the others have
        $mech->content_lacks('state unknown');
    };
};

subtest "test fiksgatami all reports page" => sub {
    FixMyStreet::override_config {
        ALLOWED_COBRANDS => [ 'fiksgatami' ],
        MAPIT_URL => 'http://mapit.nuug.no/',
    }, sub {
        $mech->create_body_ok(3, 'Oslo');
        ok $mech->host("fiksgatami.no"), 'change host to fiksgatami';
        $mech->get_ok('/reports');
        # There should only be one Oslo
        $mech->content_contains('Oslo');
        $mech->content_unlike(qr{Oslo">Oslo.*Oslo}s);
    }
};

done_testing();

