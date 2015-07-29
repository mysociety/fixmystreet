package FixMyStreet::Cobrand::Stevenage;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

sub council_id { return 2347; }
sub council_area { return 'Stevenage'; }
sub council_name { return 'Stevenage Council'; }
sub council_url { return 'stevenage'; }
sub is_two_tier { return 1; }

sub disambiguate_location {
    my $self = shift;
    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => 'Stevenage',
        centre => '51.904330,-0.189364',
        span   => '0.063112,0.087585',
        bounds => [ 51.869319, -0.234382, 51.932431, -0.146796 ],
    };
}

sub example_places {
    return [ 'SG1 1HN', 'Lyton Way' ];
}

sub default_map_zoom { return 3; }

sub users_can_hide { return 1; }

sub contact_email {
    my $self = shift;
    return join( '@', 'csc', 'stevenage.gov.uk' );
}

1;

