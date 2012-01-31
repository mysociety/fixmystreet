package FixMyStreet::Cobrand::Barnet;
use base 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

sub council_id { return 2489; }
sub council_area { return 'Barnet'; }
sub council_name { return 'Barnet Council'; }
sub council_url { return 'barnet'; }

sub disambiguate_location {
    return {
        centre => '51.612832,-0.218169',
        span   => '0.0563,0.09',
        bounds => [ '51.584682,-0.263169', '51.640982,-0.173169' ],
    };
}

1;

