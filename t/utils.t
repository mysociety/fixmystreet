#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 9;

use FindBin;
use lib "$FindBin::Bin/../perllib";
use lib "$FindBin::Bin/../commonlib/perllib";

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
