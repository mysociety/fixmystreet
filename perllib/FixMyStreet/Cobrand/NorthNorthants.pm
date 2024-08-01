=head1 NAME

FixMyStreet::Cobrand::NorthNorthants - code specific to the North Northamptonshire cobrand.

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::NorthNorthants;
use base 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;

use Moo;

# This cobrand is integrated with Kier's works manager but
# makes use of the same attributes as Alloy and validation
# checks for Confirm.
with 'FixMyStreet::Roles::ConfirmValidation';
with 'FixMyStreet::Roles::Open311Alloy';
with 'FixMyStreet::Roles::Cobrand::Northants';

=head2 Defaults

=over 4

=cut

sub council_area_id { return 164185; }
sub council_area { return 'North Northamptonshire'; }
sub council_name { return 'North Northamptonshire Council'; }
sub council_url { return 'northnorthants'; }

sub privacy_policy_url {
    'https://www.northnorthants.gov.uk/service-privacy-notices/street-doctor-privacy-notice'
}

sub enter_postcode_text { 'Enter a North Northamptonshire postcode, street name and area, or check an existing report number' }

=item * Filters down search results to remove West Northants, and be the street name and the postcode only

=cut

sub geocoder_munge_results {
    my ($self, $result) = @_;

    $result->{display_name} = '' unless $result->{display_name} =~ /North Northamptonshire/;
    $result->{display_name} =~ s/, North Northamptonshire, England//;
}

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        centre => '52.425635989845,-0.625888958117201',
        span   => '0.452023646239923,0.564659818768001',
        bounds => [ 52.1915706611928, -0.906250498116196, 52.6435943074328, -0.341590679348196 ],
    };
}

=item * Users with a northnorthants.gov.uk email can always be found in the admin.

=cut

sub admin_user_domain { 'northnorthants.gov.uk' }

sub _problems_restriction_areas { [
    '%,2398,%', # Corby.
    '%,2396,%', # Kettering.
    '%,2395,%', # Wellingborough.
    '%,164185,%', # North Northamptonshire.
] }

=item * Defects are coloured blue.

Ideally this would be in Roles::CobrandNorthants, but that can't call $self->SUPER.

=cut

sub pin_colour {
    my ($self, $p, $context) = @_;
    return 'blue' if $self->is_defect($p);
    return $self->SUPER::pin_colour($p, $context);
}

1;
