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

sub language_domain { 'FixMyBarangay' }

sub area_types {
    return [ 'BGY' ];
}

sub disambiguate_location {
    return {
        country => 'ph',
        bing_country => 'Philippines',
    };
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

sub reports_by_body { 1 }

sub default_show_name {
    my $self = shift;

    return 0 if $self->{c}->user->from_council;
    return 1;
}

1;

