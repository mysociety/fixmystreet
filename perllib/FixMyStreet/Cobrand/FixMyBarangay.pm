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

# effectively allows barangay staff to hide reports
sub council_id { return   '1,2' ; }

sub areas_on_around {
    return [ 1, 2 ];
}

sub can_support_problems {
    return 1;
}

sub default_show_name {
    my $self = shift;

    return 0 if $self->{c}->user->from_council;
    return 1;
}

# makes no sense to send questionnaires since FMB's reporters are mostly staff
sub send_questionnaires {
    return 0;
}

# let staff hide reports in their own barangay
sub users_can_hide { 1 }

1;

