package FixMyStreet::Cobrand::Warwickshire;
use base 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

sub council_area_id { return 2243; }
sub council_area { return 'Warwickshire'; }
sub council_name { return 'Warwickshire County Council'; }
sub council_url { return 'warwickshire'; }

sub is_two_tier { return 1; }

sub disambiguate_location {
    my $self = shift;
    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => 'Warwick',
        centre => '52.300638,-1.559546',
        span   => '0.73185,0.789867',
        bounds => [ 51.955394, -1.962007, 52.687244, -1.172140 ],
    };
}

sub example_places {
    return [ 'CV34 4RL', 'Stratford Rd' ];
}

sub contact_email {
    my $self = shift;
    return join( '@', 'fmstest', 'warwickshire.gov.uk' );
}
sub contact_name { 'Warwickshire County Council (do not reply)'; }

sub send_questionnaires { 0 }

1;
