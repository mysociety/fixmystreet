# FixMyStreet::Geocode::Bing
# Geocoding with Bing for FixMyStreet.
#
# Copyright (c) 2011 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Geocode::Bing;

use strict;

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
    my ( $cls, $s, $c ) = @_;

    my $params = $c->cobrand->disambiguate_location($s);
    # Allow cobrand to fixup the user input
    $s = $params->{string} if $params->{string};

    $s = FixMyStreet::Geocode::escape($s);
    $s .= '+' . $params->{town} if $params->{town} and $s !~ /$params->{town}/i;

    my $url = "http://dev.virtualearth.net/REST/v1/Locations?q=$s";
    $url .= '&userMapView=' . join(',', @{$params->{bounds}})
        if $params->{bounds};
    $url .= '&userLocation=' . $params->{centre} if $params->{centre};
    $url .= '&c=' . $params->{bing_culture} if $params->{bing_culture};

    $c->stash->{geocoder_url} = $url;
    my $js = FixMyStreet::Geocode::cache('bing', $url, 'key=' . FixMyStreet->config('BING_MAPS_API_KEY'));
    if (!$js) {
        return { error => _('Sorry, we could not parse that location. Please try again.') };
    }
    if ($js->{statusCode} ne '200') {
        return { error => _('Sorry, we could not find that location.') };
    }

    my $results = $js->{resourceSets}->[0]->{resources};
    my ( $error, @valid_locations, $latitude, $longitude );

    foreach (@$results) {
        my $address = $_->{name};
        next if $params->{bing_country} && $_->{address}->{countryRegion} ne $params->{bing_country};

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

    return { latitude => $latitude, longitude => $longitude } if scalar @valid_locations == 1;
    return { error => $error };
}

sub reverse {
    my ( $latitude, $longitude, $bing_culture ) = @_;

    # Get nearest road-type thing from Bing
    my $key = FixMyStreet->config('BING_MAPS_API_KEY', '');
    if ($key) {
        my $url = "http://dev.virtualearth.net/REST/v1/Locations/$latitude,$longitude?key=$key";
        $url .= '&c=' . $bing_culture if $bing_culture;
        my $j = FixMyStreet::Geocode::cache('bing', $url);
        return $j if $j;
    }

    return undef;
}

1;
