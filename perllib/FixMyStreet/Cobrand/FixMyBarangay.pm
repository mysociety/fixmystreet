package FixMyStreet::Cobrand::FixMyBarangay;
use base 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

sub council_id { return 0; }
sub council_area { return 'FixMyBarangay'; }
sub council_name { return 'FixMyBarangay'; }
sub council_url { return 'fmb'; }

sub disambiguate_location {
    return {
        country => 'ph',
        bing_culture => 'ph',
        bing_country => 'The Philippines'
    };
}


1;

