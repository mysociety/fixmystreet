package FixMyStreet::Cobrand::Smidsy;
use base 'FixMyStreet::Cobrand::UK';

use strict;
use warnings;

use FixMyStreet;

# http://mapit.mysociety.org/area/2247.html
use constant area_id => 2247;

use constant extra_global_fields => 1;

sub area_types          { 
    my $self = shift;
    my $area_types = $self->next::method;
    [ 
        @$area_types,
        'GLA', # Greater London Authority
    ];
} 

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    # TODO, switch on $p->category
    #

    return 'bike536'; # e.g. look for pin-bike536.png
}

# this is required to use new style templates
sub path_to_web_templates {
    my $self = shift;
    return [
        FixMyStreet->path_to( 'templates/web', $self->moniker )->stringify,
        FixMyStreet->path_to( 'templates/web/fixmystreet' )->stringify
    ];
}

1;

