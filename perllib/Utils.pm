# Utils.pm:
# Various generic utilities for FixMyStreet.
#
# Copyright (c) 2008 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Utils.pm,v 1.1 2008-10-09 14:20:54 matthew Exp $
#

package Utils;

use strict;
use DateTime;
use Encode;
use mySociety::GeoUtil;
use mySociety::Locale;
use FixMyStreet;

=head2 convert_latlon_to_en

    ( $easting, $northing ) = Utils::convert_en_to_latlon( $latitude, $longitude );

Takes the WGS84 latitude and longitude and returns OSGB36 easting and northing.

=cut

sub convert_latlon_to_en {
    my ( $latitude, $longitude, $coordsyst ) = @_;
    $coordsyst ||= 'G';

    local $SIG{__WARN__} = sub { die $_[0] };
    my ( $easting, $northing ) =
        mySociety::Locale::in_gb_locale {
            mySociety::GeoUtil::wgs84_to_national_grid( $latitude, $longitude, $coordsyst );
        };

    return ( $easting, $northing );
}

=head2 convert_en_to_latlon

    ( $latitude, $longitude ) = Utils::convert_en_to_latlon( $easting, $northing );

Takes the OSGB36 easting and northing and returns WGS84 latitude and longitude.

=cut

sub convert_en_to_latlon {
    my ( $easting, $northing ) = @_;

    my ( $latitude, $longitude ) =

      # map { truncate_coordinate($_) }
      mySociety::GeoUtil::national_grid_to_wgs84( $easting, $northing, 'G' );

    return ( $latitude, $longitude );
}

=head2 convert_en_to_latlon_truncated

    ( $lat, $lon ) = Utils::convert_en_to_latlon( $easting, $northing );

Takes the OSGB36 easting and northing and returns WGS84 latitude and longitude
(truncated using C<Utils::truncate_coordinate>).

=cut

sub convert_en_to_latlon_truncated {
    my ( $easting, $northing ) = @_;

    return
      map { truncate_coordinate($_) }
      convert_en_to_latlon( $easting, $northing );
}

=head2 truncate_coordinate

    $short = Utils::truncate_coordinate( $long );

Given a long coordinate returns a shorter one - rounded to 6 decimal places -
which is < 1m at the equator, if you're using WGS84 lat/lon.

=cut

sub truncate_coordinate {
    my $in = shift;
    my $out = mySociety::Locale::in_gb_locale {
        sprintf( '%0.6f', $in );
    };
    $out =~ s{\.?0+\z}{} if $out =~ m{\.};
    return $out;
}

=head2 trim_text

    my $text = trim_text( $text_to_trim );

Strip leading and trailing white space from a string. Also reduces all
white space to a single space.

Trim

=cut

sub trim_text {
    my $input = shift;
    for ($input) {
        last unless $_;
        s{\s+}{ }g;    # all whitespace to single space
        s{^ }{};       # trim leading
        s{ $}{};       # trim trailing
    }
    return $input;
}


=head2 cleanup_text

Tidy up text including removing contentious phrases,
SHOUTING and new lines and adding sentence casing. Takes an optional HASHREF
of args as follows.

=over

=item allow_multiline

Do not flatten down to a single line if true.

=back

=cut

sub cleanup_text {
    my $input = shift || '';
    my $args  = shift || {};

    # lowercase everything if looks like it might be SHOUTING
    $input = lc $input if $input !~ /[a-z]/;

    # clean up language and tradmarks
    for ($input) {

        # shit -> poo
        s{\bdog\s*shite*?\b}{dog poo}ig;

        # 'portakabin' to '[portable cabin]' (and variations)
        s{\b(porta)\s*([ck]abin|loo)\b}{[$1ble $2]}ig;
        s{kabin\]}{cabin\]}ig;
    }

    # Remove unneeded whitespace
    my @lines = grep { m/\S/ } split m/(?:\r?\n){2,}/, $input;
    for (@lines) {
        $_ = trim_text($_);
        $_ = ucfirst $_;       # start with capital
    }

    my $join_char = $args->{allow_multiline} ? "\n\n" : " ";
    $input = join $join_char, @lines;

    return $input;
}

sub prettify_dt {
    my ( $dt, $type ) = @_;
    $type ||= '';
    $type = 'short' if $type eq '1';

    my $now = DateTime->now( time_zone => FixMyStreet->time_zone || FixMyStreet->local_time_zone );

    my $tt = '';
    return "[unknown time]" unless ref $dt;
    $tt = $dt->strftime('%H:%M') unless $type eq 'date';

    if ($dt->strftime('%Y%m%d') eq $now->strftime('%Y%m%d')) {
        return "$tt " . _('today');
    }
    $tt .= ', ' unless $type eq 'date';
    if ($dt->strftime('%Y %U') eq $now->strftime('%Y %U')) {
        $tt .= $dt->strftime('%A');
    } elsif ($type eq 'zurich') {
        $tt .= $dt->strftime('%e. %B %Y');
    } elsif ($type eq 'short') {
        $tt .= $dt->strftime('%e %b %Y');
    } elsif ($dt->strftime('%Y') eq $now->strftime('%Y')) {
        $tt .= $dt->strftime('%A %e %B %Y');
    } else {
        $tt .= $dt->strftime('%a %e %B %Y');
    }
    $tt = decode_utf8($tt) if !utf8::is_utf8($tt);
    return $tt;
}

# argument is duration in seconds, rounds to the nearest minute
sub prettify_duration {
    my ($s, $nearest) = @_;

    unless ( defined $nearest ) {
        if ($s < 3600) {
            $nearest = 'minute';
        } elsif ($s < 3600*24) {
            $nearest = 'hour';
        } elsif ($s < 3600*24*7) {
            $nearest = 'day';
        } elsif ($s < 3600*24*7*4) {
            $nearest = 'week';
        } elsif ($s < 3600*24*7*4*12) {
            $nearest = 'month';
        } else {
            $nearest = 'year';
        }
    }

    if ($nearest eq 'year') {
        $s = int(($s+60*60*24*3.5)/60/60/24/7/4/12)*60*60*24*7*4*12;
    } elsif ($nearest eq 'month') {
        $s = int(($s+60*60*24*3.5)/60/60/24/7/4)*60*60*24*7*4;
    } elsif ($nearest eq 'week') {
        $s = int(($s+60*60*24*3.5)/60/60/24/7)*60*60*24*7;
    } elsif ($nearest eq 'day') {
        $s = int(($s+60*60*12)/60/60/24)*60*60*24;
    } elsif ($nearest eq 'hour') {
        $s = int(($s+60*30)/60/60)*60*60;
    } else { # minute
        $s = int(($s+30)/60)*60;
        return _('less than a minute') if $s == 0;
    }
    my @out = ();
    _part(\$s, 60*60*24*7*4*12, \@out);
    _part(\$s, 60*60*24*7*4, \@out);
    _part(\$s, 60*60*24*7, \@out);
    _part(\$s, 60*60*24, \@out);
    _part(\$s, 60*60, \@out);
    _part(\$s, 60,  \@out);
    return join(', ', @out);
}
sub _part {
    my ($s, $m, $o) = @_;
    if ($$s >= $m) {
        my $i = int($$s / $m);
        my $str;
        if ($m == 60*60*24*7*4*12) {
            $str = mySociety::Locale::nget("%d year", "%d years", $i);
        } elsif ($m == 60*60*24*7*4) {
            $str = mySociety::Locale::nget("%d month", "%d months", $i);
        } elsif ($m == 60*60*24*7) {
            $str = mySociety::Locale::nget("%d week", "%d weeks", $i);
        } elsif ($m == 60*60*24) {
            $str = mySociety::Locale::nget("%d day", "%d days", $i);
        } elsif ($m == 60*60) {
            $str = mySociety::Locale::nget("%d hour", "%d hours", $i);
        } else {
            $str = mySociety::Locale::nget("%d minute", "%d minutes", $i);
        }
        push @$o, sprintf($str, $i);
        $$s -= $i * $m;
    }
}


1;
