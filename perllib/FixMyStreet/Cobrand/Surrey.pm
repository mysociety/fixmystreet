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
        town => 'Surrey',

    };
}

=item * We include the C<external_id> (Zendesk reference) in the acknowledgement email.

=cut

sub report_sent_confirmation_email { 'external_id' }

=item * The default map view shows closed/fixed reports for 31 days

=cut

sub report_age {
    return {
        open => '90 days',
        closed => '31 days',
        fixed  => '31 days',
    };
}

=item * Add display_name as an extra contact field

=cut

sub contact_extra_fields { [ 'display_name' ] }

=item * We do not send alerts to report authors.

=cut

sub suppress_reporter_alerts { 1 }


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

=head2 categories_restriction

Surrey don't want a particular district category on their cobrand.

=cut

sub categories_restriction {
    my ($self, $rs) = @_;
    return $rs->search( { 'me.category' => {  -not_in => [ 'Rubbish (refuse and recycling)' ] } } );
}

=head2 dashboard_export_problems_add_columns

Surrey has an extra column in their stats export showing the number of subscribers to a report.
They are set up not to subscribe the original reporter to their own report so the alert number
is the number of users who have subscribed to the report for updates

=cut

sub dashboard_export_problems_add_columns {
    my ($self, $csv) = @_;

    $csv->add_csv_columns(
        alerts_count => "Subscribers",
    );

    my $alerts_lookup = $csv->dbi ? undef : $self->csv_update_alerts;

    $csv->csv_extra_data(sub {
        my $report = shift;

        if ($alerts_lookup) {
            return { alerts_count => ($alerts_lookup->{$report->id} || 0) };
        } else {
            return { alerts_count => ($report->{alerts_count} || 0) };
        }
    });
}

=back

=head2 Open311

=over 1

=item * Fetched reports via Open311 use the service name as their title

=cut

sub open311_title_fetched_report {
    my ($self, $request) = @_;
    return $request->{service_name};
}

1;

=back
