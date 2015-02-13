# FixMyStreet::Geocode::Google
# The geocoding functions for FixMyStreet.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Geocode::Google;

use strict;
use Utils;

# string STRING CONTEXT
# Looks up on Google Maps API, and caches, a user-inputted location.
# Returns array of (LAT, LON, ERROR), where ERROR is either undef, a string, or
# an array of matches if there are more than one. The information in the query
# may be used to disambiguate the location in cobranded versions of the site.
sub string {
    my ( $s, $c ) = @_;

    my $params = $c->cobrand->disambiguate_location($s);

    # For some reason adding gl=uk is no longer sufficient to make google
    # think we are in the UK for some locations so we explictly add UK to
    # the address.
    if ($c->cobrand->country eq 'GB' && $s !~ /, *UK/ && $s !~ /united *kingdom$/) {
        $s .= ', UK';
    }

    $s = FixMyStreet::Geocode::escape($s);

    my $url = 'http://maps.google.com/maps/geo?q=' . $s;
    $url .=  '&ll=' . $params->{centre}  if $params->{centre};
    $url .= '&spn=' . $params->{span}    if $params->{span};
    if ($params->{google_country}) {
        $url .=  '&gl=' . $params->{google_country};
    } elsif ($params->{country}) {
        $url .=  '&gl=' . $params->{country};
    }
    $url .=  '&hl=' . $params->{lang}    if $params->{lang};

    my $args = 'sensor=false&key=' . FixMyStreet->config('GOOGLE_MAPS_API_KEY');
    my $js = FixMyStreet::Geocode::cache('google', $url, $args, qr/"code":6[12]0/);
    if (!$js) {
        return { error => _('Sorry, we could not parse that location. Please try again.') };
    }
    if ($js->{Status}->{code} ne '200') {
        return { error => _('Sorry, we could not find that location.') };
    }

    my $results = $js->{Placemark};
    my ( $error, @valid_locations, $latitude, $longitude );
    foreach (@$results) {
        next unless $_->{AddressDetails}->{Accuracy} >= 4;
        my $address = $_->{address};
        next unless $c->cobrand->geocoded_string_check( $address );
        ( $longitude, $latitude ) =
            map { Utils::truncate_coordinate($_) }
            @{ $_->{Point}->{coordinates} };
        push (@$error, {
            address => $address,
            latitude => $latitude,
            longitude => $longitude
        });
        push (@valid_locations, $_);
    }
    return { latitude => $latitude, longitude => $longitude } if scalar @valid_locations == 1;
    return { error => $error };
}

1;
