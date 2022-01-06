package FixMyStreet::Cobrand::Shropshire;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

use Moo;
with 'FixMyStreet::Roles::ConfirmOpen311';
with 'FixMyStreet::Roles::ConfirmValidation';

sub council_area_id { return 2238; } # https://mapit.mysociety.org/area/2238.html
sub council_area { return 'Shropshire'; }
sub council_name { return 'Shropshire Council'; }
sub council_url { return 'shropshire'; }

sub admin_user_domain {
    'shropshire.gov.uk'
}

sub default_map_zoom { 6 }

sub send_questionnaires { 0 }

sub abuse_reports_only { 1 }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        centre => '52.6354074681479,-2.73414274873688',
        span   => '0.692130766645555,1.00264228991404',
        bounds => [ 52.3062638566609, -3.23554076944319, 52.9983946233065, -2.23289847952914 ],
    };
}

sub lookup_site_code_config { {
    buffer => 200, # metres
    url => "https://tilma.mysociety.org/mapserver/shropshire",
    srsname => "urn:ogc:def:crs:EPSG::27700",
    typename => "Street_Gazetteer",
    property => "USRN",
    accept_feature => sub { 1 }
} }

sub staff_ignore_form_disable_form {
    my $self = shift;
    my $c = $self->{c};

    return $c->user_exists
        && $c->user->belongs_to_body( $self->body->id );
}

sub open311_contact_meta_override {
    my ($self, $service, $contact, $meta) = @_;
    for my $meta_data (@$meta) {
        if ($meta_data->{'description'} && $meta_data->{'description'} =~ 'Abandoned since') {
            $meta_data->{'fieldtype'} = 'date';
            $meta_data->{'required'} = 'true';
            last;
        }
    }
}

1;
