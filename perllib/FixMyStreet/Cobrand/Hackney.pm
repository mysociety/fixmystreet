package FixMyStreet::Cobrand::Hackney;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

sub council_area_id { return 2508; }
sub council_area { return 'Hackney'; }
sub council_name { return 'Hackney Council'; }
sub council_url { return 'hackney'; }
sub send_questionnaires { 0 }

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
