use strict;
use warnings;
use Test::More;
use FixMyStreet::DB;
use FixMyStreet::Map;
use FixMyStreet::TestMech;
use DateTime;
use mySociety::Locale;

use Catalyst::Test 'FixMyStreet::App';

my $mech = FixMyStreet::TestMech->new;

mySociety::Locale::gettext_domain('FixMyStreet');

FixMyStreet::Map::set_map_class();
my $c = ctx_request('http://fixmystreet.com/test?bbox=-7.6,49.7,-7.5,49.8');

$mech->delete_user('test@example.com');
my $user =
  FixMyStreet::DB->resultset('User')
  ->find_or_create( { email => 'test@example.com', name => 'Test User' } );
ok $user, "created test user";

my $dt = DateTime->now();


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
        state              => 'fixed',
        confirmed          => $dt->ymd . ' ' . $dt->hms,
        lang               => 'en-gb',
        service            => '',
        cobrand            => 'default',
        cobrand_data       => '',
        send_questionnaire => 't',
        latitude           => '49.7668057243776',
        longitude          => '-7.55715980363992',
        user_id            => $user->id,
    }
);

for my $test ( 
    {
        state => 'fixed', 
        colour => 'yellow',
    },
    {
        state => 'fixed - user', 
        colour => 'yellow',
    },
    {
        state => 'fixed - council', 
        colour => 'yellow',
    },
    {
        state => 'confirmed', 
        colour => 'yellow',
    },
    {
        state => 'duplicate', 
        colour => 'yellow',
    },
    {
        state => 'unable to fix', 
        colour => 'yellow',
    },
    {
        state => 'not responsible', 
        colour => 'yellow',
    },
    {
        state => 'investigating', 
        colour => 'yellow',
    },
    {
        state => 'action scheduled', 
        colour => 'yellow',
    },
    {
        state => 'planned', 
        colour => 'yellow',
    },
    {
        state => 'in progress', 
        colour => 'yellow',
    },
) {
    subtest "pin colour for state $test->{state}" => sub {
        $report->state($test->{state});
        $report->update;

        my ( $pins, $around_map_list, $nearby, $dist ) =
            FixMyStreet::Map::map_pins( $c, 0, 0, 0, 0 );

        ok $pins;
        ok $around_map_list;
        ok $nearby;
        ok $dist;

        my $id = $report->id;
        my $colour = $test->{colour};

        is $pins->[0][2], $colour, 'pin colour';
    };
}

$mech->delete_user( $user );


done_testing();
