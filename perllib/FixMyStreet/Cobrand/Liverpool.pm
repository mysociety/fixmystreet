package FixMyStreet::Cobrand::Liverpool;
use base 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

sub council_id { return 2527; }
sub council_area { return 'Liverpool'; }
sub council_name { return 'Liverpool City Council'; }
sub council_url { return 'liverpool'; }

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
        town   => 'Liverpool',
        centre => '53.3954859587086,-2.91705385926665',
        span   => '0.163440332081315,0.201179283552342',
        bounds => [ 53.3115426747989, -3.01917947387853, 53.4749830068802, -2.81800019032618 ],
    };
}

1;
