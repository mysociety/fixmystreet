package FixMyStreet::Cobrand::Westminster;
use base 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

sub council_area_id { return 2504; }
sub council_area { return 'Westminster'; }
sub council_name { return 'Westminster City Council'; }
sub council_url { return 'Westminster'; }

sub disambiguate_location {
    my $self = shift;
    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => 'Westminster',
        centre => '51.513444,-0.160467',
        bounds => [ 51.483816, -0.216088, 51.539793, -0.111101 ],
    };
}

sub example_places {
    return [ 'SW1E 6QP', 'Victoria Street' ];
}

sub contact_email {
    my $self = shift;
    return join( '@', 'fmstest', 'westminster.gov.uk' );
}

sub send_questionnaires { 0 }

1;
