use Test::More;
use DateTime;

use_ok 'FixMyStreet::WorkingDays';


my $wd = FixMyStreet::WorkingDays->new(
    public_holidays => [
        '2020-09-21',
        '2020-09-15',
    ],
);

my $dt = DateTime->new(year => 2020, month => 9, day => 19);

is $wd->add_days($dt, 1)->ymd, '2020-09-22';
is $wd->sub_days($dt, 5)->ymd, '2020-09-11';
is $wd->is_public_holiday($dt), undef;
is $wd->is_weekend($dt), 1;

$wd = FixMyStreet::WorkingDays->new(
    saturdays => 1,
);
$dt = DateTime->new(year => 2020, month => 9, day => 20);

is $wd->add_days($dt, 1)->ymd, '2020-09-21';
is $wd->add_days($dt, 6)->ymd, '2020-09-26';
is $wd->is_sunday($dt), 1;

done_testing;
