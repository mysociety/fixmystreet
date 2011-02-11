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
    my $out = sprintf( '%0.6f', $in );
    $out =~ s{\.?0+\z}{} if $out =~ m{\.};
    return $out;
}

1;
