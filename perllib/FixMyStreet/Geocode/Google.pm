# FixMyStreet::Geocode::Google
# The geocoding functions for FixMyStreet.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Geocode::Google;

use strict;
use Utils;
use URI::Escape;

# string STRING CONTEXT
# Looks up on Google Maps API, and caches, a user-inputted location.
# Returns array of (LAT, LON, ERROR), where ERROR is either undef, a string, or
# an array of matches if there are more than one. The information in the query
# may be used to disambiguate the location in cobranded versions of the site.
sub string {
    my ( $cls, $s, $c ) = @_;

    my $params = $c->cobrand->disambiguate_location($s);
    # Allow cobrand to fixup the user input
    $s = $params->{string} if $params->{string};

    my $components = "";

    # For some reason adding gl=uk is no longer sufficient to make google
    # think we are in the UK for some locations so we explicitly tell Google
    # the country.
    if ($c->cobrand->country eq 'GB') {
        $components = "country:GB";
    }

    $s = FixMyStreet::Geocode::escape($s);

    my $url = 'https://maps.googleapis.com/maps/api/geocode/json?address=' . $s;
    $url .= '&bounds=' . $params->{bounds}[0] . ',' . $params->{bounds}[1]
        . '|' . $params->{bounds}[2] . ',' . $params->{bounds}[3]
        if $params->{bounds};
    if ($params->{google_country}) {
        $url .=  '&region=' . $params->{google_country};
    } elsif ($params->{country}) {
        $url .=  '&region=' . $params->{country};
    }
    if ($params->{components}) {
        $components .= ($components ? '|' : '') . URI::Escape::uri_escape_utf8($params->{components});
    }
    $url .=  '&language=' . $params->{lang} if $params->{lang};

    $url .= '&components=' . $components if $components;

    $c->stash->{geocoder_url} = $url;
    my $args = 'key=' . FixMyStreet->config('GOOGLE_MAPS_API_KEY');
    my $js = FixMyStreet::Geocode::cache('google', $url, $args, qr/"status"\s*:\s*"(OVER_QUERY_LIMIT|REQUEST_DENIED|INVALID_REQUEST|UNKNOWN_ERROR)"/);
    if (!$js) {
        return { error => _('Sorry, we could not parse that location. Please try again.') };
    }
    return unless $js->{status} eq 'OK';

    my $results = $js->{results};
    my ( $error, @valid_locations, $latitude, $longitude );
    foreach (@$results) {
        my $address = $_->{formatted_address};
        next unless $c->cobrand->geocoded_string_check( $address );
        ( $longitude, $latitude ) =
            map { Utils::truncate_coordinate($_) }
            ($_->{geometry}{location}{lng}, $_->{geometry}{location}{lat});
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
