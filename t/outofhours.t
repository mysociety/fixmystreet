use Test::More;
use Test::MockModule;
use Test::MockTime qw(:all);
use FixMyStreet::Cobrand::UK;

use_ok 'FixMyStreet::OutOfHours';

my $ukc = Test::MockModule->new('FixMyStreet::Cobrand::UK');
$ukc->mock('_get_bank_holiday_json', sub {
    {
        "england-and-wales" => {
            "events" => [
                { "date" => "2019-12-25", "title" => "Christmas Day" }
            ]
        }
    }
});

my $ooh = FixMyStreet::OutOfHours->new(holidays => FixMyStreet::Cobrand::UK->public_holidays());

set_fixed_time('2022-07-01T12:00:00Z');
is $ooh->active, 0, 'not out of hours middle of weekday';

set_fixed_time('2022-07-01T20:00:00Z');
is $ooh->active, 1, 'out of hours in evening';

set_fixed_time('2022-07-02T12:00:00Z');
is $ooh->active, 1, 'out of hours at weekend';

set_fixed_time('2019-12-25T12:00:00Z');
is $ooh->active, 1, 'out of hours on bank holiday';

done_testing;
