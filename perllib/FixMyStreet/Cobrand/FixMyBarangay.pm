package FixMyStreet::Cobrand::FixMyBarangay;
use base 'FixMyStreet::Cobrand::Default';

use strict;
use warnings;

sub get_council_sender {
    my ( $self, $area_id, $area_info ) = @_;

    my $send_method;

    my $council_config = FixMyStreet::App->model("DB::Open311conf")->search( { area_id => $area_id } )->first;
    $send_method = $council_config->send_method if $council_config;

    return $send_method if $send_method;

    return 'Email';
}

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
    return ( 'BGY' );
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

1;

