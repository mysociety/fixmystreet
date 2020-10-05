package FixMyStreet::Cobrand::CentralBedfordshire;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

sub council_area_id { 21070 }
sub council_area { 'Central Bedfordshire' }
sub council_name { 'Central Bedfordshire Council' }
sub council_url { 'centralbedfordshire' }
sub send_questionnaires { 0 }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        centre => '52.006697,-0.436005',
        bounds => [ 51.805087, -0.702181, 52.190913, -0.143957 ],
    };
}

sub open311_munge_update_params {
    my ($self, $params, $comment, $body) = @_;

    # TODO: This is the same as Bexley - could be factored into its own Role.
    $params->{service_request_id_ext} = $comment->problem->id;

    my $contact = $comment->problem->contact;
    $params->{service_code} = $contact->email;
}

sub open311_extra_data_include {
    my ($self, $row, $h, $extra, $contact) = @_;

    my $cfg = $self->feature('area_code_mapping') || return;
    my @areas = split ',', $row->areas;
    my @matches = grep { $_ } map { $cfg->{$_} } @areas;
    if (@matches) {
        return [
            { name => 'area_code', value => $matches[0] },
        ];
    }
}

1;
