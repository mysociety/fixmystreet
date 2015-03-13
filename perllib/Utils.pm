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
use File::Slurp qw();
use mySociety::GeoUtil;
use mySociety::Locale;

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

sub barnet_categories {
    # The values here are KBIDs from Barnet's system: see bin/send-reports for formatting.
    # They are no longer used since Barnet switched to email for delivery of problem reports.
    # and can be removed when SendReport/Barnet.pm is removed.
    if (mySociety::Config::get('STAGING_SITE')) { # note staging site must use different KBIDs
        return {
             'Street scene misc'        => 14 # for test
        }
    } else {
        return {
            'Accumulated Litter'        => 349,
            'Dog Bin'                   => 203,
            'Dog Fouling'               => 288,
            'Drain or Gully'            => 256,
            'Fly Posting'               => 465,
            'Fly Tipping'               => 449,
            'Graffiti'                  => 292,
            'Gritting'                  => 200,
            'Highways'                  => 186,
            'Litter Bin Overflowing'    => 205,
            'Manhole Cover'             => 417,
            'Overhanging Foliage'       => 421,
            'Pavement Damaged/Cracked'  => 195,
            'Pothole'                   => 204,
            'Road Sign'                 => 80,
            'Roadworks'                 => 246,
            'Street Lighting'           => 251,
        };
    }
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
        $tt .= decode_utf8($dt->strftime('%A'));
    } elsif ($type eq 'zurich') {
        $tt .= decode_utf8($dt->strftime('%e. %B %Y'));
    } elsif ($type eq 'short') {
        $tt .= decode_utf8($dt->strftime('%e %b %Y'));
    } elsif ($dt->strftime('%Y') eq $now->strftime('%Y')) {
        $tt .= decode_utf8($dt->strftime('%A %e %B %Y'));
    } else {
        $tt .= decode_utf8($dt->strftime('%a %e %B %Y'));
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
        if ($m == 60*60*24*7) {
            $str = mySociety::Locale::nget("%d week", "%d weeks", $i);
        } elsif ($m == 60*60*24) {
            $str = mySociety::Locale::nget("%d day", "%d days", $i);
        } elsif ($m == 60*60) {
            $str = mySociety::Locale::nget("%d hour", "%d hours", $i);
        } elsif ($m == 60) {
            $str = mySociety::Locale::nget("%d minute", "%d minutes", $i);
        }
        push @$o, sprintf($str, $i);
        $$s -= $i * $m;
    }
}

=head2 read_file

Reads in a UTF-8 encoded file using File::Slurp and decodes it from UTF-8.
This appears simplest, rather than getting confused with binmodes and so on.

=cut
sub read_file {
    my $filename = shift;
    my $data = File::Slurp::read_file( $filename );
    $data = Encode::decode( 'utf8', $data );
    return $data;
}

1;
