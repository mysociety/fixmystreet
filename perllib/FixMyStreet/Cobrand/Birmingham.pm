package FixMyStreet::Cobrand::Birmingham;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

sub council_area_id { return 2514; }
sub council_area { return 'Birmingham'; }
sub council_name { return 'Birmingham City Council'; }
sub council_url { return 'birmingham'; }

sub example_places {
    return ( 'B30 2UR', "Edwin Road" );
}

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    my $town = 'Birmingham';

    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => $town,
        centre => '52.4885651179828,-1.87472344112158',
        span   => '0.227657174041433,0.304797268430542',
        bounds => [ 52.3810216319423, -2.03366116615742, 52.6086788059837, -1.72886389772688 ],
    };
}

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'grey' if $p->state eq 'not responsible';
    return 'green' if $p->is_fixed || $p->is_closed;
    return 'red' if $p->state eq 'confirmed';
    return 'yellow';
}

sub send_questionnaires {
    return 0;
}

1;
