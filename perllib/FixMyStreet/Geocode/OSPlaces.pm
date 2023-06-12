=head1 NAME

FixMyStreet:Geocode::OSPlaces - OS Places API reverse geocoding for FixMyStreet

=cut

package FixMyStreet::Geocode::OSPlaces;

use strict;
use warnings;
use FixMyStreet::Geocode;

my $BASE = 'https://api.os.uk/search/places/v1/nearest?dataset=LPI&fq=CLASSIFICATION_CODE:M*+CLASSIFICATION_CODE:C*+CLASSIFICATION_CODE:R*+CLASSIFICATION_CODE:Z*&srs=WGS84';

sub reverse_geocode {
    my ($cls, $cobrand, $latitude, $longitude) = @_;
    if (my $key = $cobrand->feature('os_places_api_key')) {
        my $url = "$BASE&key=$key&point=$latitude,$longitude";
        my $j = FixMyStreet::Geocode::cache('osplaces', $url);
        return $j ? $j->{results}[0] : undef;
    }
    return undef;
}

1;
