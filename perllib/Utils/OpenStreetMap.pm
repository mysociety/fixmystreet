package Utils::OpenStreetMap;

use strict;
use warnings;
use Exporter 'import';
use POSIX qw(ceil);

our @EXPORT_OK = qw(short_url);

my $chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_~";

sub short_url {
    my ($lat, $lon, $zoom) = @_;
    $zoom ||= 16;
    my $x = ($lon + 180) * 2**32 / 360;
    my $y = ($lat +  90) * 2**32 / 180;
    my $code = _interleave($x, $y);

    my $str = '';
    # add eight to the zoom level, which approximates an accuracy of
    # one pixel in a tile
    my $n = ceil(($zoom + 8) / 3) - 1;
    for my $i (0..$n) {
        my $digit = ($code >> (58 - 6 * $i)) & 0x3f;
        $str .= substr($chars, $digit, 1);
    }
    # append characters onto the end of the string to represent
    # partial zoom levels (characters themselves have a granularity
    # of 3 zoom levels).
    $str .= "-" x (($zoom + 8) % 3);
    return "http://osm.org/go/$str";
}

sub _interleave {
    my ($x, $y) = @_;
    my $c = 0;
    for (my $i=31; $i>=0; $i--) {
        $c = ($c << 1) | (($x >> $i) & 1);
        $c = ($c << 1) | (($y >> $i) & 1);
    }
    return $c;
}

1;
