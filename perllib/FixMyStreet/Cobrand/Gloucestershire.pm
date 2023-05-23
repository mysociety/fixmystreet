=head1 NAME

FixMyStreet::Cobrand::Gloucestershire - code specific to the Gloucestershire cobrand

=head1 SYNOPSIS

We integrate with Gloucestershire's Confirm back end.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Gloucestershire;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

use Moo;

=pod

Confirm backends expect some extra values and have some maximum lengths for
certain fields. These roles implement that behaviour.

=cut

with 'FixMyStreet::Roles::ConfirmOpen311';
with 'FixMyStreet::Roles::ConfirmValidation';

=head2 Defaults

=over 4

=cut

sub council_area_id { '2226' }
sub council_area { 'Gloucestershire' }
sub council_name { 'Gloucestershire County Council' }
sub council_url { 'gloucestershire' }

=item * Users with a gloucestershire.gov.uk email can always be found in the admin.

=cut

sub admin_user_domain { 'gloucestershire.gov.uk' }

=item * Allows anonymous reporting

=cut

sub allow_anonymous_reports { 'button' }

=item * Gloucestershire use their own privacy policy

=cut

sub privacy_policy_url {
    'https://www.gloucestershire.gov.uk/council-and-democracy/data-protection/privacy-notices/gloucestershire-county-council-general-privacy-statement/gloucestershire-county-council-general-privacy-statement/'
}

=item * We do not send questionnaires.

=cut

sub send_questionnaires { 0 }

=pod

=back

=cut

sub disambiguate_location {
    my $self = shift;
    my $string = shift;

    my $town = 'Gloucestershire';

    # As it's the requested example location, try to avoid a disambiguation page
    $town .= ', GL20 5XA'
        if $string =~ /^\s*gloucester\s+r(oa)?d,\s*tewkesbury\s*$/i;

    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => $town,
        centre => '51.825508771929094,-2.1263689427866654',
        span   => '0.53502964014244,1.07233523662321',
        bounds => [
            51.57753580138198, -2.687537158717889,
            52.11256544152442, -1.6152019220946803,
        ],
    };
}

# TODO Sending currently fails
sub lookup_site_code_config {
    {
        buffer => 200, # metres
    }
}

1;
