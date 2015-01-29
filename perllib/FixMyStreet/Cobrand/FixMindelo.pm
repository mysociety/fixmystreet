package FixMyStreet::Cobrand::FixMindelo;
use base 'FixMyStreet::Cobrand::Default';

use strict;
use warnings;

sub country {
    return 'CV';
}

sub languages { [ 'pt-cv,Portuguese,pt_CV' ] }
sub language_override { 'pt-cv' }

sub disambiguate_location {
    return {
        country => 'cv',
        bing_country => 'Cape Verde',
    };
}

# let staff hide reports
sub users_can_hide { 1 }

1;

