# FixMyStreet::Geocode::OSNames
# Geocoding with OS Names API for FixMyStreet.

package FixMyStreet::Geocode::OSNames;

use strict;

use FixMyStreet::Geocode;
use Utils;

# string STRING CONTEXT
# Looks up on OS Names API, and caches, a user-inputted location.
# Returns array of (LAT, LON, ERROR), where ERROR is either undef, a string, or
# an array of matches if there are more than one. The information in the query
# may be used to disambiguate the location in cobranded versions of the site.
sub string {
    my ( $cls, $s, $c ) = @_;

    my $params = $c->cobrand->disambiguate_location($s);
    my $key = $params->{key};

    $s = $params->{string} if $params->{string};
    $s = FixMyStreet::Geocode::escape($s);

    my $url = "https://api.ordnancesurvey.co.uk/opennames/v1/find?maxresults=10";
    $url .= "&query=$s";
    $url .= '&fq=BBOX:' . join(',', @{$params->{bounds_en}})
        if $params->{bounds_en};

    my $js = FixMyStreet::Geocode::cache('osnames', $url, 'key=' . $key);
    if (!$js) {
        return { error => _('Sorry, we could not parse that location. Please try again.') };
    }

    my $results = $js->{results};
    my ( $error, @valid_locations, $latitude, $longitude );

    foreach (map { $_->{GAZETTEER_ENTRY} } @$results) {
        my $address = $_->{NAME1} . ", " . $_->{POSTCODE_DISTRICT};
        next if $params->{match_borough} && $_->{DISTRICT_BOROUGH} ne $params->{match_borough};
        next if $params->{match_unitary} && $_->{COUNTY_UNITARY} ne $params->{match_unitary};
        next if $params->{match_place} && $_->{POPULATED_PLACE} ne $params->{match_place};

        ( $latitude, $longitude ) =
            Utils::convert_en_to_latlon_truncated($_->{GEOMETRY_X}, $_->{GEOMETRY_Y});
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
