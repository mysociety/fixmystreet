package FixMyStreet::Cobrand::Warwickshire;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

sub council_id { return 2243; } # http://mapit.mysociety.org/area/2243.html
sub council_area { return 'Warwickshire'; }
sub council_name { return 'Warwickshire Council'; }
sub council_url { return 'warwickshire'; }

sub path_to_web_templates {
    my $self = shift;
    return [
        FixMyStreet->path_to( 'templates/web', $self->moniker )->stringify,
        FixMyStreet->path_to( 'templates/web/default' )->stringify
    ];
}

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
    return [ 'CV34 3BU', 'Stratford Rd' ];
}


1;
