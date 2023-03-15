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

=item * We do not send questionnaires.

=cut

sub send_questionnaires { 0 }

=pod

=back

=cut

# TODO Sending currently fails
sub lookup_site_code_config {
    {
        buffer => 200, # metres
    }
}

1;
