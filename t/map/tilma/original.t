use FixMyStreet::DB;
use FixMyStreet::Map;
use FixMyStreet::TestMech;
use DateTime;

use Catalyst::Test 'FixMyStreet::App';

my $mech = FixMyStreet::TestMech->new;

FixMyStreet::Map::set_map_class();
my $c = ctx_request('http://fixmystreet.com/test?bbox=-7.6,49.7,-7.5,49.8');

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
        $c->stash->{report_age_field} = 'lastupdate';

        my ($on_map, $nearby) = FixMyStreet::Map::map_features($c, bbox => "0,0,0,0");

        ok $on_map;
        ok $nearby;

        my $id = $report->id;
        my $colour = $test->{colour};

        my $pin_colour = $c->cobrand->pin_colour($on_map->[0], 'around');
        is $pin_colour, $colour, 'pin colour';
    };
}

done_testing();
