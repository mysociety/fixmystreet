package FixMyStreet::Cobrand::Barnet;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

sub council_id { return 2489; }
sub council_area { return 'Barnet'; }
sub council_name { return 'Barnet Council'; }
sub council_url { return 'barnet'; }

sub path_to_web_templates {
    my $self = shift;
    return [
        FixMyStreet->path_to( 'templates/web', $self->moniker )->stringify,
        FixMyStreet->path_to( 'templates/web/fixmystreet' )->stringify
    ];
}

sub disambiguate_location {
    my $self = shift;
    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => 'Barnet',
        centre => '51.612832,-0.218169',
        span   => '0.0563,0.09',
        bounds => [ 51.584682, -0.263169, 51.640982, -0.173169 ],
    };
}

sub example_places {
    return [ 'N11 1NP', 'Wood St' ];
}

1;

