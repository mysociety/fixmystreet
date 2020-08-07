package FixMyStreet::Cobrand::CentralBedfordshire;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

sub council_area_id { return 21070; }
sub council_area { return 'Central Bedfordshire'; }
sub council_name { return 'Central Bedfordshire Council'; }
sub council_url { return 'centralbedfordshire'; }
sub send_questionnaires { 0 }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        centre => '52.006697,-0.436005',
        bounds => [ 51.805087, -0.702181, 52.190913, -0.143957 ],
    };
}

1;
