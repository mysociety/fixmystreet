#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

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
}

my @cleanup_tests = (
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

done_testing();
