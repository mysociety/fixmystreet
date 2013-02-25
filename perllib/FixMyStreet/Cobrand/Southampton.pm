package FixMyStreet::Cobrand::Southampton;
use base 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

sub council_id { return 2567; }
sub council_area { return 'Southampton'; }
sub council_name { return 'Southampton City Council'; }
sub council_url { return 'southampton'; }

sub disambiguate_location {
    my $self = shift;
    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => 'Southampton',
        centre => '50.913822,-1.400493',
        span   => '0.084628,0.15701',
        bounds => [ 50.871508, -1.478998, 50.956136, -1.321988 ],
    };
}

sub send_questionnaires { return 0; }

1;

