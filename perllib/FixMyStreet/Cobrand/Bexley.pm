package FixMyStreet::Cobrand::Bexley;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

sub council_area_id { 2494 }
sub council_area { 'Bexley' }
sub council_name { 'London Borough of Bexley' }
sub council_url { 'bexley' }
sub example_places { ( 'DA6 7AT', "Chieveley Road" ) }
sub get_geocoder { 'OSM' }

sub enable_category_groups { 1 }

sub base_url {
    my $self = shift;
    return $self->next::method() if FixMyStreet->config('STAGING_SITE');
    # uncoverable statement
    return 'https://fix.bexley.gov.uk';
}

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        centre => '51.46088,0.142359',
        bounds => [ 51.408484, 0.074653, 51.515542, 0.2234676 ],
    };
}

sub on_map_default_status { 'open' }

sub contact_email {
    my $self = shift;
    return join( '@', 'customer.services', $self->council_url . '.gov.uk' );
}

sub open311_munge_update_params {
    my ($self, $params, $comment, $body) = @_;

    $params->{service_request_id_ext} = $comment->problem->id;

    my $contact = $comment->result_source->schema->resultset("Contact")->not_deleted->find({
        body_id => $body->id,
        category => $comment->problem->category
    });
    $params->{service_code} = $contact->email;
}

sub lookup_site_code_config {
    # uncoverable function
    # uncoverable statement
    {
        buffer => 200, # metres
        url => "https://tilma.mysociety.org/mapserver/bexley",
        srsname => "urn:ogc:def:crs:EPSG::27700",
        typename => "Streets",
        property => "NSG_REF",
        accept_feature => sub { 1 }
    }
}

sub open311_config {
    my ($self, $row, $h, $params) = @_;

    my $extra = $row->get_extra_fields;

    # Reports made via the app probably won't have a NSGRef because we don't
    # display the road layer. Instead we'll look up the closest asset from the
    # WFS service at the point we're sending the report over Open311.
    if (!$row->get_extra_field_value('NSGRef')) {
        if (my $ref = $self->lookup_site_code($row)) {
            push @$extra, { name => 'NSGRef', description => 'NSG Ref', value => $ref };
        }
    }

    $row->set_extra_fields(@$extra);
}

1;
