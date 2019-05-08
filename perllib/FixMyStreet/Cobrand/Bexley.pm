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
sub suggest_duplicates { 1 }

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

1;
