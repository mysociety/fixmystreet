package FixMyStreet::Cobrand::FixMindelo;
use base 'FixMyStreet::Cobrand::Default';

use strict;
use warnings;


sub country {
    return 'CV';
}

sub language_domain { 'FixMindelo' }

sub disambiguate_location {
    return {
        country => 'cv',
        bing_country => 'Cape Verde',
    };
}

# let staff hide reports
sub users_can_hide { 1 }

1;

