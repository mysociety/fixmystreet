package FixMyStreet::Cobrand::Surrey;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

use FixMyStreet::Geocode::Address;

sub council_area_id { 2242 }
sub council_area { 'Surrey' }
sub council_name { 'Surrey County Council' }
sub council_url { 'surrey' }
sub is_two_tier { 1 }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        centre => '51.2478663,-0.4205895',
        span   => '0.4000678,0.9071629',
        bounds => [ 51.0714965, -0.8489465, 51.4715643, 0.0582164 ],
    };
}

sub report_sent_confirmation_email { 'id' }


=head2 get_town

Returns the name of the town from the problem's geocode information, if present.

=cut

sub get_town {
    my ($self, $p) = @_;

    return unless $p->geocode;
    my $geocode = FixMyStreet::Geocode::Address->new($p->geocode);
    my $address = $geocode->{LPI} || $geocode->{address} || ($geocode->can('address') ? $geocode->address : '');
    return unless $address;
    my $town = $address->{town} || $address->{city} || $address->{TOWN_NAME} || $address->{locality} || $address->{village} || $address->{suburb};
    return $town;
}

1;
