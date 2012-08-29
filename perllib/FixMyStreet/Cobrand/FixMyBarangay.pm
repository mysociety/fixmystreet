package FixMyStreet::Cobrand::FixMyBarangay;
use base 'FixMyStreet::Cobrand::Default';

use strict;
use warnings;

sub path_to_web_templates {
    my $self = shift;
    return [
        FixMyStreet->path_to( 'templates/web', $self->moniker )->stringify,
        FixMyStreet->path_to( 'templates/web/fixmystreet' )->stringify
    ];
}

sub country {
    return 'PH';
}

sub area_types {
    return [ 'BGY' ];
}

sub disambiguate_location {
    return {
        country => 'ph',
        bing_country => 'Philippines',
    };
}

sub site_title {
    my ($self) = @_;
    return 'FixMyBarangay';
}

sub only_authed_can_create {
    return 1;
}

sub areas_on_around {
    return [ 1, 2 ];
}

sub can_support_problems {
    return 1;
}

1;

