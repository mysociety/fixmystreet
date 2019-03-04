package FixMyStreet::Cobrand::Hounslow;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

sub council_area_id { 2483 }
sub council_area { 'Hounslow' }
sub council_name { 'Hounslow Borough Council' }
sub council_url { 'hounslow' }
sub example_places { ( 'TW3 1SN', "Depot Road" ) }

sub base_url {
    my $self = shift;
    return $self->next::method() if FixMyStreet->config('STAGING_SITE');
    return 'https://fms.hounslowhighways.org';
}

sub disambiguate_location {
    my $self = shift;
    my $string = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        centre => '51.468495,-0.366134',
        bounds => [ 51.420739, -0.461502, 51.502850, -0.243443 ],
    };
}

sub on_map_default_status { 'open' }

sub contact_email {
    my $self = shift;
    return join( '@', 'enquiries', $self->council_url . 'highways.org' );
}

sub send_questionnaires { 0 }

1;
