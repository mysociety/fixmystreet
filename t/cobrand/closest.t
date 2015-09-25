use strict;
use warnings;

use Test::More;

use mySociety::Locale;
use FixMyStreet::DB;
use FixMyStreet::TestMech;

my $mech = FixMyStreet::TestMech->new;

use_ok 'FixMyStreet::Cobrand';

mySociety::Locale::gettext_domain( 'FixMyStreet' );

my $c = FixMyStreet::Cobrand::UK->new();

my $user =
  FixMyStreet::DB->resultset('User')
  ->find_or_create( { email => 'test@example.com', name => 'Test User' } );
ok $user, "created test user";

my $dt = DateTime->new(
    year   => 2011,
    month  => 04,
    day    => 16,
    hour   => 15,
    minute => 47,
    second => 23
);

my $report = FixMyStreet::DB->resultset('Problem')->find_or_create(
    {
        postcode           => 'SW1A 1AA',
        bodies_str         => '2504',
        areas              => ',105255,11806,11828,2247,2504,',
        category           => 'Other',
        title              => 'Test 2',
        detail             => 'Test 2 Detail',
        used_map           => 't',
        name               => 'Test User',
        anonymous          => 'f',
        state              => 'closed',
        confirmed          => $dt->ymd . ' ' . $dt->hms,
        lang               => 'en-gb',
        service            => '',
        cobrand            => 'default',
        cobrand_data       => '',
        send_questionnaire => 't',
        latitude           => '51.5016605453401',
        longitude          => '-0.142497580865087',
        user_id            => $user->id,
    }
);
my $report_id = $report->id;
ok $report, "created test report - $report_id";

$report->geocode( undef );

ok !$report->geocode, 'no geocode entry for report';

my $near = $c->find_closest( $report->latitude, $report->longitude, $report );

SKIP: {
    if (!FixMyStreet->config('BING_MAPS_API_KEY')) {
        skip 'No Bing Maps key', 0;
    }

    ok $report->geocode, 'geocode entry added to report';
    ok $report->geocode->{resourceSets}, 'geocode entry looks like right sort of thing';

    like $near, qr/Constitution Hill/i, 'nearest street looks right';
    like $near, qr/Nearest postcode .*: SW1A 1AA/i, 'nearest postcode looks right';

    $near = $c->find_closest_address_for_rss( $report->latitude, $report->longitude, $report );

    like $near, qr/Constitution Hill/i, 'nearest street for RSS looks right';
    unlike $near, qr/Nearest postcode/i, 'no nearest postcode in RSS text';

    $report->geocode( undef );
    $near = $c->find_closest_address_for_rss( $report->latitude, $report->longitude, $report );

    ok !$near, 'no closest address for RSS if not cached';
}

# all done
$mech->delete_user( $user );
done_testing();
