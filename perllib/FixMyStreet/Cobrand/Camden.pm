package FixMyStreet::Cobrand::Camden;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

sub council_area_id { return 2505; }
sub council_area { return 'Camden'; }
sub council_name { return 'Camden Council'; }
sub council_url { return 'camden'; }
sub get_geocoder { 'OSM' }
sub cut_off_date { '2023-02-01' }

sub enter_postcode_text { 'Enter a Camden postcode or street name' }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    my $town = 'Camden';

    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => $town,
        centre => '51.546390811297,-0.157422262955539',
        span   => '0.0603011959324533,0.108195286339115',
        bounds => [ 51.5126591342049, -0.213511484504216, 51.5729603301373, -0.105316198165101 ],
    };
}

sub send_questionnaires {
    return 0;
}

sub privacy_policy_url {
    'https://www.camden.gov.uk/data-protection-privacy-and-cookies'
}

sub admin_user_domain { 'camden.gov.uk' }

sub lookup_site_code_config {
    my ($self, $property) = @_;

    # uncoverable subroutine
    # uncoverable statement
    {
        buffer => 1000, # metres
        url => "https://tilma.mysociety.org/mapserver/camden",
        srsname => "urn:ogc:def:crs:EPSG::27700",
        typename => "Streets",
        property => $property,
        accept_feature => sub { 1 },
    }
}

sub open311_extra_data_include {
    my ($self, $row, $h, $contact) = @_;

    # Reports made via the app probably won't have a NSGRef because we don't
    # display the road layer. Instead we'll look up the closest asset from the
    # WFS service at the point we're sending the report over Open311.
    if (!$row->get_extra_field_value('NSGRef')) {
        if (my $ref = $self->lookup_site_code($row, 'NSG_REF')) {
            $row->update_extra_field({ name => 'NSGRef', description => 'NSG Ref', value => $ref });
        }
    }

    return [];
}

sub open311_config {
    my ($self, $row, $h, $params) = @_;
    $params->{multi_photos} = 1;
}

sub open311_munge_update_params {
    my ($self, $params, $comment, $body) = @_;
    $params->{service_request_id_ext} = $comment->problem->id;

    my $contact = $comment->problem->contact;
    $params->{service_code} = $contact->email;
}

=head2 categories_restriction

Camden don't want TfL's River Piers categories on their cobrand.

=cut

sub categories_restriction {
    my ($self, $rs) = @_;

    return $rs->search( { 'me.category' => { -not_like => 'River Piers%' } } );
}

# Problems and comments are always treated as anonymous so the user's name isn't displayed.
sub is_problem_anonymous { 1 }

sub is_comment_anonymous { 1 }

sub social_auth_enabled {
    my $self = shift;

    return $self->feature('oidc_login') ? 1 : 0;
}

sub user_from_oidc {
    my ($self, $payload) = @_;

    # Extract the user's name and email address from the payload.
    my $name = $payload->{name};
    my $email = $payload->{preferred_username};

    return ($name, $email);
}

1;
