=head1 NAME

FixMyStreet:Geocode::OSPlaces - OS Places API reverse geocoding for FixMyStreet

=cut

package FixMyStreet::Geocode::OSPlaces;

use strict;
use warnings;
use FixMyStreet::Geocode;

my $BASE = 'https://api.os.uk/search/places/v1/nearest?dataset=LPI&srs=WGS84&radius=1000';

sub reverse_geocode {
    my ($cls, $cobrand, $latitude, $longitude, $classes) = @_;
    $classes = ['M*', 'C*', 'R*', 'Z*'] unless $classes;
    if (my $key = $cobrand->feature('os_places_api_key')) {
        my $url = "$BASE&key=$key&point=$latitude,$longitude";
        if ($classes) {
            $url .= '&' . _classes_to_query_string($classes);
        }
        my $j = FixMyStreet::Geocode::cache('osplaces', $url);
        return $j ? $j->{results}[0] : undef;
    }
    return undef;
}

sub _classes_to_query_string {
    my $classes = shift;
    return 'fq=' . join('+', map { "CLASSIFICATION_CODE:$_" } @$classes);
}

1;
