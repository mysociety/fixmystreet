=head1 NAME

FixMyStreet::Cobrand::Warwickshire - code specific to the Warwickshire cobrand [incomplete]

=head1 SYNOPSIS

We integrate with Warwickshire's Open311 back end.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Warwickshire;
use base 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

=head2 Defaults

=over 4

=cut

sub council_area_id { return 2243; }
sub council_area { return 'Warwickshire'; }
sub council_name { return 'Warwickshire County Council'; }
sub council_url { return 'warwickshire'; }

=item * Warwickshire is a two-tier authority.

=cut

sub is_two_tier { return 1; }

=item * We do not send questionnaires.

=cut

sub send_questionnaires { 0 }

=pod

=back

=cut

sub disambiguate_location {
    my $self = shift;
    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => 'Warwick',
        centre => '52.300638,-1.559546',
        span   => '0.73185,0.789867',
        bounds => [ 51.955394, -1.962007, 52.687244, -1.172140 ],
    };
}

sub open311_contact_meta_override {
    my ($self, $service, $contact, $meta) = @_;

    $contact->set_extra_metadata( id_field => 'external_id');

    @$meta = grep { $_->{code} ne 'closest_address' } @$meta;
}

1;
