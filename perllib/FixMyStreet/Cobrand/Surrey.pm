package FixMyStreet::Cobrand::Surrey;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

sub council_area_id { return 2242; }
sub council_area { return 'Surrey'; }
sub council_name { return 'Surrey County Council'; }
sub council_url { return 'surrey'; }

sub example_places {
    return ( 'GU1 1TT', "Ashley Road, Walton" );
}

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        centre => '51.247811,-0.420581',
        span   => '0.400076,0.790687',
        bounds => [ 51.071435, -0.848925, 51.471511, -0.058238 ],
    };
}

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    #return 'grey' if $p->state eq 'not responsible';
    #return 'green' if $p->is_fixed || $p->is_closed;
    #return 'red' if $p->state eq 'confirmed';
    return 'yellow';
}

sub send_questionnaires {
    return 0;
}

1;
