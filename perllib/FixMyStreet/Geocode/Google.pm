#!/usr/bin/perl
#
# FixMyStreet::Geocode
# The geocoding functions for FixMyStreet.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Geocode::Google;

use strict;
use Encode;
use File::Slurp;
use File::Path ();
use LWP::Simple;
use Digest::MD5 qw(md5_hex);
use mySociety::Locale;

# string STRING CONTEXT
# Looks up on Google Maps API, and caches, a user-inputted location.
# Returns array of (LAT, LON, ERROR), where ERROR is either undef, a string, or
# an array of matches if there are more than one. The information in the query
# may be used to disambiguate the location in cobranded versions of the site.
sub string {
    my ( $s, $c ) = @_;

    my $params = $c->cobrand->disambiguate_location($s);

    $s = FixMyStreet::Geocode::escape($s);

    my $url = 'http://maps.googleapis.com/maps/api/geocode/json?address=' . $s; 
    # my $url = 'http://maps.google.com/maps/geo?q=' . $s;

    $url .=  '&latlng=' . $params->{centre} if $params->{centre};
    # $url .= '&spn=' . $params->{span}    if $params->{span};
    if ($params->{google_country}) {
        $url .=  '&components=country:' . $params->{google_country};
    } elsif ($params->{country}) {
        $url .=  '&components=country:' . $params->{country};
    }
    $url .=  '&language=' . $params->{lang} if $params->{lang};
    $url .= '&sensor=false';

    my $cache_dir = FixMyStreet->config('GEO_CACHE') . 'google/';
    my $cache_file = $cache_dir . md5_hex($url);
    my $js;
    if (-s $cache_file) {
        $js = File::Slurp::read_file($cache_file);
    } else {
        $js = LWP::Simple::get($url);
        $js = encode_utf8($js) if utf8::is_utf8($js);
        File::Path::mkpath($cache_dir);
        File::Slurp::write_file($cache_file, $js) if $js && $js !~ /"code":6[12]0/;
    }

    if (!$js) {
        return { error => _('Sorry, we could not parse that location. Please try again.') };
    }

    $js = JSON->new->utf8->allow_nonref->decode($js);
    if ($js->{status} ne 'OK') {
        return { error => _('Sorry, we could not find that location.') };
    }

    my $results = $js->{results};
    my ( $error, @valid_locations, $latitude, $longitude );
    foreach (@$results) {
        my $address = $_->{formatted_address};
        next unless $c->cobrand->geocoded_string_check( $address );
        $latitude = $_->{geometry}->{location}->{lat};
        $longitude = $_->{geometry}->{location}->{lng};
	push(@$error, {
	    address => $address,
	    latitude => sprintf('%0.6f', $latitude),
	    longitude => sprintf('%0.6f', $longitude)	  
	     });
    }
    return { latitude => $latitude, longitude => $longitude } if scalar @valid_locations == 1;
    return { error => $error };
}

1;
