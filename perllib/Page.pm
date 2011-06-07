#!/usr/bin/perl

package Page;

use strict;
use Encode;
use POSIX qw(strftime);
use Memcached;
use Problems;
use Cobrand;
use mySociety::Config;
use mySociety::Locale;

BEGIN {
    (my $dir = __FILE__) =~ s{/[^/]*?$}{};
    mySociety::Config::set_file("$dir/../conf/general");
}

sub prettify_epoch {
    my ($s, $short) = @_;
    my @s = localtime($s);
    my $tt = strftime('%H:%M', @s);
    my @t = localtime();
    if (strftime('%Y%m%d', @s) eq strftime('%Y%m%d', @t)) {
        $tt = "$tt " . _('today');
    } elsif (strftime('%Y %U', @s) eq strftime('%Y %U', @t)) {
        $tt = "$tt, " . decode_utf8(strftime('%A', @s));
    } elsif ($short) {
        $tt = "$tt, " . decode_utf8(strftime('%e %b %Y', @s));
    } elsif (strftime('%Y', @s) eq strftime('%Y', @t)) {
        $tt = "$tt, " . decode_utf8(strftime('%A %e %B %Y', @s));
    } else {
        $tt = "$tt, " . decode_utf8(strftime('%a %e %B %Y', @s));
    }
    return $tt;
}

# argument is duration in seconds, rounds to the nearest minute
sub prettify_duration {
    my ($s, $nearest) = @_;
    if ($nearest eq 'week') {
        $s = int(($s+60*60*24*3.5)/60/60/24/7)*60*60*24*7;
    } elsif ($nearest eq 'day') {
        $s = int(($s+60*60*12)/60/60/24)*60*60*24;
    } elsif ($nearest eq 'hour') {
        $s = int(($s+60*30)/60/60)*60*60;
    } elsif ($nearest eq 'minute') {
        $s = int(($s+30)/60)*60;
        return _('less than a minute') if $s == 0;
    }
    my @out = ();
    _part(\$s, 60*60*24*7, _('%d week'), _('%d weeks'), \@out);
    _part(\$s, 60*60*24, _('%d day'), _('%d days'), \@out);
    _part(\$s, 60*60, _('%d hour'), _('%d hours'), \@out);
    _part(\$s, 60, _('%d minute'), _('%d minutes'), \@out);
    return join(', ', @out);
}
sub _part {
    my ($s, $m, $w1, $w2, $o) = @_;
    if ($$s >= $m) {
        my $i = int($$s / $m);
        push @$o, sprintf(mySociety::Locale::nget($w1, $w2, $i), $i);
        $$s -= $i * $m;
    }
}

1;
