package FixMyStreet::Cobrand::Hackney;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

sub council_area_id { 2508 }
sub council_area { 'Hackney' }
sub council_name { 'Hackney Borough Council' }
sub council_url { 'hackney' }
sub admin_user_domain { 'hackney.gov.uk' }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        centre => '51.552267,-0.063316',
        bounds => [ 51.519814, -0.104511, 51.577784, -0.016527 ],
    };
}

1;
