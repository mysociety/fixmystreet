use FixMyStreet::Test;
use POSIX qw(tzset);

my $d;

BEGIN {
    use File::Basename qw(dirname);
    use File::Spec;
    $d = dirname(File::Spec->rel2abs(__FILE__));
}

use lib "$d/../../../bin/oxfordshire";

use_ok 'open311_services';

my $old_tz = $ENV{TZ};
$ENV{TZ} = 'Europe/London';
tzset;

is get_utc_iso8601_string('2018-06-01 13:37:42'), '2018-06-01T12:37:42Z', 'convert local to iso UTC';

is get_date_or_nothing('2018-06-01T12:37:42Z'), '2018-06-01 12:37:42', 'convert date format';
is get_date_or_nothing('2018-06-01T12:37Z'), '2018-06-01 12:37:00', 'convert date format add seconds';
is get_date_or_nothing('2018-06-01T12:37:42Z', 1), '2018-06-01', 'convert date format and ignore time';
is get_date_or_nothing('2018/06/01 12:37:42'), '', 'convert date returns nothing if no match';

is get_date_or_nothing('2018-06-07T12:35:08+01:00'), '2018-06-07 12:35:08', 'convert date format with TZ';

$ENV{TZ} = 'Europe/Rome';
tzset;

is get_utc_iso8601_string('2018-06-01 14:37:42'), '2018-06-01T12:37:42Z', 'convert local to iso UTC alt TZ';

$ENV{TZ} = $old_tz;
tzset;

done_testing();
