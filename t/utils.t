#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use mySociety::Locale;
mySociety::Locale::gettext_domain('FixMyStreet');

use Utils;

my @truncate_tests = (
    [ '1.1234567890123', '1.123457', "truncate down" ],
    [ '1.123456',        '1.123456', "leave untouched" ],
    [ '1.12',            '1.12',     "don't extend" ],
    [ '1.100000001',     '1.1',      "knock off trailing zeros" ],
    [ '1.000000001',     '1',        "knock off trailing zeros" ],
    [ '0.0',             '0',        "knock off trailing zeros" ],
    [ '+123',            '123',      "drop plus sign" ],
    [ '-123',            '-123',     "keep minus sign" ],
);

foreach my $test (@truncate_tests) {
    my ( $in, $out, $msg ) = @$test;
    is Utils::truncate_coordinate($in), $out, $msg;
}

my @convert_en_to_latlon_tests = (

    # e     n     lat        lon
    [ 1234, 4567, 49.808509, -7.544784 ],
);

foreach my $test (@convert_en_to_latlon_tests) {
    my ( $e, $n, $lat, $lon ) = @$test;
    is_deeply    #
      [ Utils::convert_en_to_latlon_truncated( $e, $n ) ],    #
      [ $lat, $lon ],                                         #
      "convert ($e,$n) to ($lat,$lon)";
    is_deeply
      [ Utils::convert_latlon_to_en( $lat, $lon ) ],
      [ $e, $n ],
      "convert ($lat,$lon) to ($e,$n)";
}

my @cleanup_tests = (
    [ '', '', '' ],
    [ 'dog shit', 'Dog poo', 'dog poo' ],
    [ 'dog   shit', 'Dog poo', 'with spaces' ],
    [ 'dog shite', 'Dog poo', 'with extra e' ],
    [ 'there is dog shit here', 'There is dog poo here', 'with surrounding text' ],
    [ 'portacabin', '[portable cabin]', 'cabin' ],
    [ 'portaloo', '[portable loo]', 'loo' ],
    [ 'porta loo', '[portable loo]', 'with spaces' ],
    [ '   this is a report    ', 'This is a report', 'leading and trailing spaces' ],
    [ 'This     is a   report    ', 'This is a report', 'spaces in the middle' ],
    [ 'I AM SHOUTING AT YOU', 'I am shouting at you', 'all shouting' ],
    [ 'I am EMPHASISING something', 'I am EMPHASISING something', 'some shouting' ],
    [ "This has new\n\n\nlines in it", 'This has new Lines in it', 'no new lines' ],
);

foreach my $test ( @cleanup_tests ) {
    is Utils::cleanup_text( $test->[0]), $test->[1], $test->[2];
}

is Utils::cleanup_text( "This has new\n\n\nlines in it", { allow_multiline => 1 } ),  "This has new\n\nLines in it", 'new lines allowed';


is Utils::prettify_dt(), "[unknown time]";
my $dt = DateTime->now;
is Utils::prettify_dt($dt), $dt->strftime("%H:%M today");

# Same week test
if ($dt->day_of_week == 7) { # Sunday
    $dt = DateTime->now->add(days => 1);
} else {
    $dt = DateTime->now->subtract(days => 1);
}
is Utils::prettify_dt($dt), $dt->strftime("%H:%M, %A");

if ($dt->month == 1) { # January
    $dt = DateTime->now->add(days => 30);
} else {
    $dt = DateTime->now->subtract(days => 30);
}
is Utils::prettify_dt($dt), $dt->strftime("%H:%M, %A %e %B %Y");
is Utils::prettify_dt($dt, "date"), $dt->strftime("%A %e %B %Y");
is Utils::prettify_dt($dt, "zurich"), $dt->strftime("%H:%M, %e. %B %Y");
is Utils::prettify_dt($dt, "short"), $dt->strftime("%H:%M, %e %b %Y");
is Utils::prettify_dt($dt, 1), $dt->strftime("%H:%M, %e %b %Y");
$dt = DateTime->now->subtract(days => 400);
is Utils::prettify_dt($dt), $dt->strftime("%H:%M, %a %e %B %Y");

is Utils::prettify_duration(12*5*7*86400+3600+60+1, 'year'), '1 year';
is Utils::prettify_duration(25*5*7*86400+3600+60+1, 'year'), '2 years';
is Utils::prettify_duration(5*7*86400+3600+60+1, 'month'), '1 month';
is Utils::prettify_duration(7*86400+3600+60+1, 'week'), '1 week';
is Utils::prettify_duration(86400+3600+60+1, 'day'), '1 day';
is Utils::prettify_duration(86400+3600+60+1, 'hour'), '1 day, 1 hour';
is Utils::prettify_duration(86400+3600+60+1, 'minute'), '1 day, 1 hour, 1 minute';
is Utils::prettify_duration(20, 'minute'), 'less than a minute';
# prettify_duration should choose a $nearest sensibly if it's not given
is Utils::prettify_duration(12*5*7*86400+3600+60+1), '1 year';
is Utils::prettify_duration(7*86400+3600+60+1), '1 week';
is Utils::prettify_duration(14*86400+3600+60+1), '2 weeks';
is Utils::prettify_duration(1800), '30 minutes';

done_testing();
