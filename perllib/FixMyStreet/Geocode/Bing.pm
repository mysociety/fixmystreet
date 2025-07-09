# FixMyStreet::Geocode::Bing
# Geocoding with Bing for FixMyStreet.
#
# Copyright (c) 2011 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Geocode::Bing;

use strict;
use warnings;

use FixMyStreet::Geocode;
use Utils;

sub setup {
    my $cls = shift;
    return 1 if FixMyStreet->config('BING_MAPS_API_KEY');
    return 0;
}

# string STRING CONTEXT
# Looks up on Bing Maps API, and caches, a user-inputted location.
# Returns array of (LAT, LON, ERROR), where ERROR is either undef, a string, or
# an array of matches if there are more than one. The information in the query
# may be used to disambiguate the location in cobranded versions of the site.
sub string {
    my ( $cls, $s, $cobrand ) = @_;

    my $params = $cobrand->disambiguate_location($s);
    # Allow cobrand to fixup the user input
    $s = $params->{string} if $params->{string};

    $s = FixMyStreet::Geocode::escape($s);
    $s .= '+' . $params->{town} if $params->{town} and $s !~ /$params->{town}/i;

    my $url = "https://dev.virtualearth.net/REST/v1/Locations?q=$s";
    $url .= '&userMapView=' . join(',', @{$params->{bounds}})
        if $params->{bounds};
    $url .= '&userLocation=' . $params->{centre} if $params->{centre};
    $url .= '&userIp=127.0.0.1'; # So server location does not affect results
    $url .= '&maxResults=10'; # Match what is said in the front end
    $url .= '&c=' . $params->{bing_culture} if $params->{bing_culture};

    my $out = { geocoder_url => $url };
    my $js = FixMyStreet::Geocode::cache('bing', $url, 'key=' . FixMyStreet->config('BING_MAPS_API_KEY'));
    if (!$js) {
        return { %$out, error => _('Sorry, we could not parse that location. Please try again.') };
    }
    if ($js->{statusCode} ne '200') {
        return { %$out, error => _('Sorry, we could not find that location.') };
    }

    my $results = $js->{resourceSets}->[0]->{resources};
    my ( $error, @valid_locations, $latitude, $longitude );

    # If there are any High/Medium confidence results, don't include Low ones
    my $exclude_low;
    foreach (@$results) {
        my $confidence = $_->{confidence};
        if ($confidence eq 'High' || $confidence eq 'Medium') {
            $exclude_low = 1;
            last;
        }
    }
    if ($exclude_low) {
        @$results = grep { $_->{confidence} ne 'Low' } @$results;
    }

    foreach (@$results) {
        my $address = $_->{name};
        if ($params->{bing_country}) {
            next if $_->{address}->{countryRegion} ne $params->{bing_country};
            $address =~ s/, $params->{bing_country}$//;
        }
        if ($address !~ /$_->{address}->{locality}/) {
            $address .= ", $_->{address}->{locality}";
        }

        # Getting duplicate, yet different, results from Bing sometimes
        next if @valid_locations
            && $_->{address}{postalCode} && $valid_locations[-1]{address}{postalCode} eq $_->{address}{postalCode}
            && ( $valid_locations[-1]{address}{locality} eq $_->{address}{adminDistrict2}
                || $valid_locations[-1]{address}{adminDistrict2} eq $_->{address}{locality}
                || $valid_locations[-1]{address}{locality} eq $_->{address}{locality}
               );

        ( $latitude, $longitude ) =
            map { Utils::truncate_coordinate($_) }
            @{ $_->{point}->{coordinates} };
        push (@$error, {
            address => $address,
            latitude => $latitude,
            longitude => $longitude
        });
        push (@valid_locations, $_);
    }

    return { %$out, latitude => $latitude, longitude => $longitude } if scalar @valid_locations == 1;
    return { %$out, error => $error };
}

sub reverse_geocode {
    my ( $cls, $cobrand, $latitude, $longitude ) = @_;

    my $bing_culture = $cobrand->disambiguate_location()->{bing_culture};

    # Get nearest road-type thing from Bing
    my $key = FixMyStreet->config('BING_MAPS_API_KEY', '');
    if ($key) {
        my $url = "https://dev.virtualearth.net/REST/v1/Locations/$latitude,$longitude?key=$key";
        $url .= '&c=' . $bing_culture if $bing_culture;
        my $j = FixMyStreet::Geocode::cache('bing', $url);
        return $j if $j;
    }

    return undef;
}

1;
