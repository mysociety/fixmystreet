=head1 NAME

FixMyStreet::Cobrand::Hertfordshire - code specific to the Hertfordshire cobrand

=head1 SYNOPSIS

Hertfordshire is a two-tier authority, with a Confirm backend.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Hertfordshire;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

use Moo;

=pod

Confirm backends expect some extra values and have some maximum lengths
for certain fields, implemented with a couple of roles.

=cut

with 'FixMyStreet::Roles::ConfirmOpen311';
with 'FixMyStreet::Roles::ConfirmValidation';

sub council_area_id { 2228 }
sub council_area { 'Hertfordshire' }
sub council_name { 'Hertfordshire County Council' }
sub council_url { 'hertfordshire' }

=item * Hertfordshire is a two-tier authority

=cut

sub is_two_tier { 1 }

=item * Users with a hertfordshire.gov.uk email can always be found in the admin.

=cut

sub admin_user_domain { 'hertfordshire.gov.uk' }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;
    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => 'Hertfordshire',
        centre => '51.8297420015,-0.2169596578',
        span   => '0.480850078,0.9414647506',
        bounds => [ 51.599590846, -0.745851007, 52.080440924, 0.1956137436 ],
        result_strip => ', Hertfordshire, England',
    };
}

1;
