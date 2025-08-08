=head1 NAME

FixMyStreet::Cobrand::SouthKesteven - code specific to the South Kesteven cobrand

=head1 SYNOPSIS

Does not integrate with any backend.

South Kesteven is a district council, within the county of Lincolnshire.


=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::SouthKesteven;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

use Moo;

=head2 Defaults

=over 4

=cut

sub council_area_id { '2380' }
sub council_area { 'South Kesteven' }
sub council_name { 'South Kesteven District Council' }
sub council_url { 'southkesteven' }
sub is_two_tier { 1 }

=item * Users with a southkesteven.gov.uk email can always be found in the admin.

=cut

sub admin_user_domain { 'southkesteven.gov.uk' }

=item * Has their own privacy policy.

=cut

sub privacy_policy_url {
    'https://www.southkesteven.gov.uk/your-council-and-democracy/data-protection-and-freedom-information/privacy-notice'
}

=item * Doesn't use their name in the enter postcode text.

=cut

sub enter_postcode_text { 'Enter a nearby UK postcode, or street name and area' }

=head2 body_disallows_state_change

Determines whether state of a report can be updated, based on user and current
report state.

The original reporter can reopen a closed/fixed report.

Note: Staff permissions are handled separately, via relevant_staff_user
check.

=back

=cut

sub body_disallows_state_change {
    my ( $self, $problem ) = @_;

    if (   $self->{c}->user_exists
        && $self->{c}->user->id eq $problem->user->id )
    {
        return $problem->is_open ? 1 : 0;
    }

    return 1;
}

sub disambiguate_location {
    my $self = shift;
    my $string = shift;
    return {
        %{ $self->SUPER::disambiguate_location() },
        centre => '52.8544740244351,-0.518259216392906',
        span   => '0.41973543009572,0.591815705612347',
        bounds => [
            52.6402363580567, -0.804316148045751,
            53.0599717881525, -0.212500442433404
        ],
        result_only_if => 'South Kesteven',
        result_strip => ', South Kesteven, Lincolnshire, England',
    };
}

=head2 dashboard_export_problems_add_columns

We have various additional columns for extra report data.

=cut

sub dashboard_export_problems_add_columns {
    my ($self, $csv) = @_;

    $csv->add_csv_columns(
        type_of_waste => 'Type of waste',
        how_much => 'How much waste',
        location => 'Location',
    );

    $csv->csv_extra_data(sub {
        my $report = shift;
        my $data = {
            type_of_waste => $csv->_extra_field($report, 'type_of_waste'),
            how_much => $csv->_extra_field($report, 'how_much'),
            location => $csv->_extra_field($report, 'location'),
        };
        return $data;
    });
}

1;
