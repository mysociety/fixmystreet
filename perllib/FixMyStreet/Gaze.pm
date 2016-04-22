package FixMyStreet::Gaze;

use strict;
use warnings;

use mySociety::Gaze;

sub get_radius_containing_population ($$) {
    my ($lat, $lon) = @_;

    my $dist = eval {
        mySociety::Locale::in_gb_locale {
            mySociety::Gaze::get_radius_containing_population($lat, $lon, 200_000);
        };
    };
    if ($@) {
        # Error fetching from gaze, let's fall back to 10km
        $dist = 10;
    }
    $dist = int( $dist * 10 + 0.5 ) / 10.0;
    return $dist;
}

1;
