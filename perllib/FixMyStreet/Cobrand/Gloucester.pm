=head1 NAME

FixMyStreet::Cobrand::Gloucester - code specific to the Gloucester cobrand

=head1 SYNOPSIS

We integrate with Gloucester's Alloy back end.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Gloucester;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

use Moo;

=head2 Defaults

=over 4

=cut

sub council_area_id { '2325' }
sub council_area { 'Gloucester' }
sub council_name { 'Gloucester City Council' }
sub council_url { 'gloucester' }

=item * Users with a gloucester.gov.uk email can always be found in the admin.

=cut

sub admin_user_domain { 'gloucester.gov.uk' }

=item * Allows anonymous reporting

=cut

sub allow_anonymous_reports { 'button' }

=item * Gloucester use their own privacy policy

=cut

sub privacy_policy_url {
    'https://www.gloucester.gov.uk/council-and-democracy/data-protection/privacy-notices/gloucester-county-council-general-privacy-statement/gloucester-county-council-general-privacy-statement/'
}

=item * Users can not reopen reports

=cut

sub reopening_disallowed {
    my ($self, $problem) = @_;

    # Only staff can reopen reports.
    my $c = $self->{c};
    my $user = $c->user;
    return 0 if ($c->user_exists && $user->from_body && $user->from_body->cobrand_name eq $self->council_name);
    return 1;
}

=item * We do not send questionnaires.

=cut

sub send_questionnaires { 0 }

=item * TODO: Don't show reports before the go-live date

=cut

# sub cut_off_date { '2024-03-31' }

=pod

=back

=cut

sub disambiguate_location {
    my $self = shift;
    my $string = shift;

    my $town = 'Gloucester';

    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => $town,
        centre => '51.8493825813624,-2.24025312382298',
        span   => '0.0776436939868574,0.12409536555503',
        bounds => [
            51.8075803711933, -2.30135343437398,
            51.8852240651802, -2.17725806881895
        ],
    };
}

1;
