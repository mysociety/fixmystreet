#!/usr/bin/perl
#
# FixMyStreet::Geocode
# The geocoding functions for FixMyStreet.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Geocode;

use strict;
use Encode;
use File::Slurp;
use File::Path ();
use LWP::Simple;
use Digest::MD5 qw(md5_hex);
use URI::Escape;

use mySociety::Config;
use mySociety::Locale;
use mySociety::MaPit;
use mySociety::PostcodeUtil;
use mySociety::Web qw(NewURL);

BEGIN {
    (my $dir = __FILE__) =~ s{/[^/]*?$}{};
    mySociety::Config::set_file("$dir/../../conf/general");
}

# lookup STRING QUERY
# Given a user-inputted string, try and convert it into co-ordinates using either
# MaPit if it's a postcode, or Google Maps API otherwise. Returns an array of
# data, including an error if there is one (which includes a location being in 
# Northern Ireland). The information in the query may be used by cobranded versions
# of the site to diambiguate locations.
sub lookup {
    my ($s, $c) = @_;
    my ($latitude, $longitude, $error);
    if ( $c->cobrand->country eq 'GB') {
        if ($s =~ /^\d+$/) {
            $error = 'FixMyStreet is a UK-based website that currently works in England, Scotland, and Wales. Please enter either a postcode, or a Great British street name and area.';
        } elsif (mySociety::PostcodeUtil::is_valid_postcode($s)) {
            my $location = mySociety::MaPit::call('postcode', $s);
            unless ( $error = mapit_check_error( $c, $location ) ) {
                $latitude  = $location->{wgs84_lat};
                $longitude = $location->{wgs84_lon};
            }
        }
    } elsif ( $c->cobrand->country eq 'NO') {
        if ($s =~ /^\d{4}$/) {
            my $location = mySociety::MaPit::call('postcode', $s);
            unless ( $error = mapit_check_error( $c, $location ) ) {
                $latitude  = $location->{wgs84_lat};
                $longitude = $location->{wgs84_lon};
            }
        }
    }
    unless ($error || defined $latitude) {
        ($latitude, $longitude, $error) = FixMyStreet::Geocode::string($s, $c);
    }
    return ($latitude, $longitude, $error);
}

sub geocoded_string_coordinates {
    my ( $c, $js ) = @_;
    my ($latitude, $longitude, $error);
    my ($accuracy) = $js =~ /"Accuracy" *: *(\d)/;
    if ($accuracy < 4) {  
        $error = _('Sorry, that location appears to be too general; please be more specific.');
    } elsif ( $js =~ /"coordinates" *: *\[ *(.*?), *(.*?),/ ) {
        $longitude = $1;
        $latitude  = $2;
    }
    return ($latitude, $longitude, $error);
}

sub results_check {
    my $c = shift;
    my ($error, @valid_locations);
    foreach (@_) {
        next unless /"address" *: *"(.*?)"/s;
        my $address = $1;
        next unless $c->cobrand->geocoded_string_check( $address );
        next if $address =~ /BT\d/;
        push (@$error, $address);
        push (@valid_locations, $_); 
    }
    if (scalar @valid_locations == 1) {
        return geocoded_string_coordinates( $c, $valid_locations[0] );
    }
    $error = _('Sorry, we could not find that location.') unless $error;
    return (undef, undef, $error);
}

# string STRING QUERY
# Canonicalises, looks up on Google Maps API, and caches, a user-inputted location.
# Returns array of (LAT, LON, ERROR), where ERROR is either undef, a string, or
# an array of matches if there are more than one. The information in the query
# may be used to disambiguate the location in cobranded versions of the site. 
sub string {
    my ($s, $c) = @_;
    $s = lc($s);
    $s =~ s/[^-&\w ']/ /g;
    $s =~ s/\s+/ /g;
    $s = URI::Escape::uri_escape_utf8($s);
    $s = $c->cobrand->disambiguate_location( "q=$s" );
    $s =~ s/%20/+/g;
    my $url = 'http://maps.google.com/maps/geo?' . $s;
    my $cache_dir = mySociety::Config::get('GEO_CACHE');
    my $cache_file = $cache_dir . md5_hex($url);
    my ($js, $error);
    if (-s $cache_file) {
        $js = File::Slurp::read_file($cache_file);
    } else {
        # For some reason adding gl=uk is no longer sufficient to make google
        # think we are in the UK for some locations so we explictly add UK to
        # the address. We do it here so as not to invalidate existing cache
        # entries
        if (   $c->cobrand->country eq 'GB'
            && $url !~ /,\+UK/
            && $url !~ /united\++kingdom$/ )
        {
            if ( $url =~ /&/ ) {
                $url =~ s/&/,+UK&/;
            } else {
                $url .= ',+UK';
            }
        }
        $url .= '&sensor=false&key=' . mySociety::Config::get('GOOGLE_MAPS_API_KEY');
        $js = LWP::Simple::get($url);
        $js = encode_utf8($js) if utf8::is_utf8($js);
        File::Path::mkpath($cache_dir);
        File::Slurp::write_file($cache_file, $js) if $js && $js !~ /"code":6[12]0/;
    }
    if (!$js) {
        $error = _('Sorry, we could not parse that location. Please try again.');
    } elsif ($js !~ /"code" *: *200/) {
        $error = _('Sorry, we could not find that location.');
    } elsif ($js =~ /}, *{/) { # Multiple
        return results_check($c, (split /}, *{/, $js));
    } elsif ($js =~ /BT\d/) {
        # Northern Ireland, hopefully
        $error = _("We do not cover Northern Ireland, I'm afraid, as our licence doesn't include any maps for the region.");
    } else {
        return results_check($c, $js);
    }
    return (undef, undef, $error);
}

sub mapit_check_error {
    my ( $c, $location ) = @_;
    if ($location->{error}) {
        return _('That postcode was not recognised, sorry.') if $location->{code} =~ /^4/;
        return $location->{error};
    }
    if ( $c->cobrand->country eq 'GB') {
        my $island = $location->{coordsyst};
        if (!$island) {
            return _("Sorry, that appears to be a Crown dependency postcode, which we don't cover.");
        }
        if ($island eq 'I') {
            return _("We do not cover Northern Ireland, I'm afraid, as our licence doesn't include any maps for the region.");
        }
    }
    return 0;
}

1;
