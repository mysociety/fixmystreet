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

use mySociety::Locale;
use mySociety::MaPit;
use mySociety::PostcodeUtil;
use mySociety::Web qw(NewURL);

# lookup STRING CONTEXT
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
    unless ($error || defined $latitude) {
        $error = _('Sorry, we could not find that location.');
    }
    return ($latitude, $longitude, $error);
}

# string STRING CONTEXT
# Canonicalises, and then passes to some external API to look stuff up.
sub string {
    my ($s, $c) = @_;
    $s = lc($s);
    $s =~ s/[^-&\w ']/ /g;
    $s =~ s/\s+/ /g;
    $s = URI::Escape::uri_escape_utf8($s);
    $s =~ s/%20/+/g;
    my $params = $c->cobrand->disambiguate_location();
    if ( FixMyStreet->config('BING_MAPS_API_KEY') ) {
        my $lookup = FixMyStreet::Geocode::string_bing($s, $c, $params);
        return ( $lookup->{latitude}, $lookup->{longitude}, $lookup->{error} );
    }
    if ( FixMyStreet->config('GOOGLE_MAPS_API_KEY') ) {
        my $lookup = FixMyStreet::Geocode::string_google($s, $c, $params);
        return ( $lookup->{latitude}, $lookup->{longitude}, $lookup->{error} );
    }
}

# string_google STRING CONTEXT
# Looks up on Google Maps API, and caches, a user-inputted location.
# Returns array of (LAT, LON, ERROR), where ERROR is either undef, a string, or
# an array of matches if there are more than one. The information in the query
# may be used to disambiguate the location in cobranded versions of the site.
sub string_google {
    my ( $s, $c, $params ) = @_;

    my $url = 'http://maps.google.com/maps/geo?q=' . $s;
      $url .=  '&ll=' . $params->{centre}  if $params->{centre};
      $url .= '&spn=' . $params->{span}    if $params->{span};
      $url .=  '&gl=' . $params->{country} if $params->{country};
      $url .=  '&hl=' . $params->{lang}    if $params->{lang};

    my $cache_dir = FixMyStreet->config('GEO_CACHE') . 'google/';
    my $cache_file = $cache_dir . md5_hex($url);
    my $js;
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
        $url .= '&sensor=false&key=' . FixMyStreet->config('GOOGLE_MAPS_API_KEY');
        $js = LWP::Simple::get($url);
        $js = encode_utf8($js) if utf8::is_utf8($js);
        File::Path::mkpath($cache_dir);
        File::Slurp::write_file($cache_file, $js) if $js && $js !~ /"code":6[12]0/;
    }

    if (!$js) {
        return { error => _('Sorry, we could not parse that location. Please try again.') };
    } elsif ($js =~ /BT\d/) {
        # Northern Ireland, hopefully
        return { error => _("We do not cover Northern Ireland, I'm afraid, as our licence doesn't include any maps for the region.") };
    }

    $js = JSON->new->utf8->allow_nonref->decode($js);
    if ($js->{Status}->{code} ne '200') {
        return { error => _('Sorry, we could not find that location.') };
    }

    my $results = $js->{Placemark};
    my ( $error, @valid_locations, $latitude, $longitude );
    foreach (@$results) {
        next unless $_->{AddressDetails}->{Accuracy} >= 4;
        my $address = $_->{address};
        next unless $c->cobrand->geocoded_string_check( $address );
        ( $longitude, $latitude ) = @{ $_->{Point}->{coordinates} };
        push (@$error, $address);
        push (@valid_locations, $_);
    }
    return { latitude => $latitude, longitude => $longitude } if scalar @valid_locations == 1;
    return { error => $error };
}

# string_bing STRING CONTEXT
# Looks up on Bing Maps API, and caches, a user-inputted location.
# Returns array of (LAT, LON, ERROR), where ERROR is either undef, a string, or
# an array of matches if there are more than one. The information in the query
# may be used to disambiguate the location in cobranded versions of the site.
sub string_bing {
    my ( $s, $c, $params ) = @_;
    my $url = "http://dev.virtualearth.net/REST/v1/Locations?q=$s&c=en-GB"; # FIXME nb-NO for Norway
    $url .= '&mapView=' . $params->{bounds}[0] . ',' . $params->{bounds}[1]
        if $params->{bounds};
    $url .= '&userLocation=' . $params->{centre} if $params->{centre};

    my $cache_dir = FixMyStreet->config('GEO_CACHE') . 'bing/';
    my $cache_file = $cache_dir . md5_hex($url);
    my $js;
    if (-s $cache_file) {
        $js = File::Slurp::read_file($cache_file);
    } else {
        $url .= '&key=' . FixMyStreet->config('BING_MAPS_API_KEY');
        $js = LWP::Simple::get($url);
        $js = encode_utf8($js) if utf8::is_utf8($js);
        File::Path::mkpath($cache_dir);
        File::Slurp::write_file($cache_file, $js) if $js;
    }

    if (!$js) {
        return { error => _('Sorry, we could not parse that location. Please try again.') };
    } elsif ($js =~ /BT\d/) {
        return { error => _("We do not cover Northern Ireland, I'm afraid, as our licence doesn't include any maps for the region.") };
    }

    $js = JSON->new->utf8->allow_nonref->decode($js);
    if ($js->{statusCode} ne '200') {
        return { error => _('Sorry, we could not find that location.') };
    }

    my $results = $js->{resourceSets}->[0]->{resources};
    my ( $error, @valid_locations, $latitude, $longitude );
    foreach (@$results) {
        my $address = $_->{name};
        next unless $_->{address}->{countryRegion} eq 'United Kingdom'; # FIXME This is UK only
        ( $latitude, $longitude ) = @{ $_->{point}->{coordinates} };
        push (@$error, $address);
        push (@valid_locations, $_);
    }
    return { latitude => $latitude, longitude => $longitude } if scalar @valid_locations == 1;
    return { error => $error };
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
