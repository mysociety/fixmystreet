#!/usr/bin/perl
#
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
use mySociety::DBHandle qw(dbh);
use mySociety::GeoUtil;
use mySociety::Locale;

sub workaround_pg_bytea {
    my ( $st, $img_idx, @elements ) = @_;
    my $s = dbh()->prepare($st);
    for ( my $i = 1 ; $i <= @elements ; $i++ ) {
        if ( $i == $img_idx ) {
            $s->bind_param(
                $i,
                $elements[ $i - 1 ],
                { pg_type => DBD::Pg::PG_BYTEA }
            );
        }
        else {
            $s->bind_param( $i, $elements[ $i - 1 ] );
        }
    }
    $s->execute();
}

=head2 convert_latlon_to_en

    ( $easting, $northing ) = Utils::convert_en_to_latlon( $latitude, $longitude );

Takes the WGS84 latitude and longitude and returns OSGB36 easting and northing.

=cut

sub convert_latlon_to_en {
    my ( $latitude, $longitude ) = @_;

    my ( $easting, $northing ) =
        mySociety::Locale::in_gb_locale {
            mySociety::GeoUtil::wgs84_to_national_grid( $latitude, $longitude, 'G' );
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

sub london_categories {
    return {
        'Abandoned vehicle' => 'AbandonedVehicle',
        'Car parking' => 'Parking',
        'Dangerous structure' => 'DangerousStructure',
        'Dead animal' => 'DeadAnimal',
        'Dumped cylinder' => 'DumpedCylinder',
        'Dumped rubbish' => 'DumpedRubbish',
        'Flyposting' => 'FlyPosting',
        'Graffiti' => 'Graffiti',
        'Litter bin' => 'LitterBin',
        'Public toilet' => 'PublicToilet',
        'Refuse collection' => 'RefuseCollection',
        'Road or pavement defect' => 'Road',
        'Road or pavement obstruction' => 'Obstruction',
        'Skip problem' => 'Skip',
        'Street cleaning' => 'StreetCleaning',
        'Street drainage' => 'StreetDrainage',
        'Street furniture' => 'StreetFurniture',
        'Street needs gritting' => 'StreetGritting',
        'Street lighting' => 'StreetLighting',
        'Street sign' => 'StreetSign',
        'Traffic light' => 'TrafficLight',
        'Tree (dangerous)' => 'DangerousTree',
        'Tree (fallen branches)' => 'FallenTree',
        'Untaxed vehicle' => 'UntaxedVehicle',
    };
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
        s{\bdog\s*shit\b}{dog poo}ig;

        # 'portakabin' to '[portable cabin]' (and variations)
        s{\b(porta)\s*([ck]abin|loo)\b}{[$1ble $2]}ig;
        s{kabin\]}{cabin\]}ig;
    }

    # Remove unneeded whitespace
    my @lines = grep { m/\S/ } split m/\n\n/, $input;
    for (@lines) {
        $_ = trim_text($_);
        $_ = ucfirst $_;       # start with capital
    }

    my $join_char = $args->{allow_multiline} ? "\n\n" : " ";
    $input = join $join_char, @lines;

    return $input;
}

1;
