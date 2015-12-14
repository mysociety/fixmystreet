package FixMyStreet::Cobrand::Angus;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

sub council_id { return 2550; }
sub council_area { return 'Angus'; }
sub council_name { return 'Angus Council'; }
sub council_url { return 'angus'; }

sub enter_postcode_text {
    my ($self) = @_;
    return 'Enter an Angus postcode, or street name and area';
}

sub example_places {
    return ( 'DD8 3AP', "Canmore Street" );
}

sub default_show_name { 0 }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        town => 'Angus',
        centre => '56.7240845983561,-2.91774391131183',
        span   => '0.525195055746977,0.985870680170788',
        bounds => [ 56.4616875530489, -3.40703662677109, 56.9868826087959, -2.4211659466003 ],
    };
}

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'grey' if $p->state eq 'not responsible';
    return 'green' if $p->is_fixed || $p->is_closed;
    return 'red' if $p->state eq 'confirmed';
    return 'yellow';
}

sub contact_email {
    my $self = shift;
    return join( '@', 'accessline', 'angus.gov.uk' );
}

1;
