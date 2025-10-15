=head1 NAME

FixMyStreet::Cobrand::Greenwich - code specific to the Greenwich cobrand

=head1 SYNOPSIS

Greenwich use their own Open311 endpoint, backing on to MS Dynamics.

=cut

package FixMyStreet::Cobrand::Greenwich;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use Moo;

use strict;
use warnings;

with 'FixMyStreet::Roles::Cobrand::OpenUSRN';

=head2 Defaults

=over 4

=cut

sub council_area_id { return 2493; }
sub council_area { return 'Royal Borough of Greenwich'; }
sub council_name { return 'Royal Borough of Greenwich'; }
sub council_url { return 'greenwich'; }

=item * We use slightly different text on the geocode form.

=cut

sub enter_postcode_text {
    my ($self) = @_;
    return 'Enter a Royal Greenwich postcode, or street name and area';
}

=item * We only shows 20 reports per page on the map.

=cut

sub reports_per_page { return 20; }

=item * Users with a royalgreenwich.gov.uk email can always be found in the admin.

=cut

sub admin_user_domain { 'royalgreenwich.gov.uk' }

=item * We do not send questionnaires.

=cut

sub send_questionnaires { 0 }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    my $town = 'Greenwich';

    # as it's the requested example location, try to avoid a disambiguation page
    $town .= ', SE10 0EF' if $string =~ /^\s*woolwich\s+r(?:oa)?d\s*(?:,\s*green\w+\s*)?$/i;

    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => $town,
        centre => '51.4743770385684,0.0555696523982184',
        span   => '0.089851200483885,0.150572372434415',
        bounds => [ 51.423679096602, -0.0263872255863898, 51.5135302970859, 0.124185146848025 ],
        result_strip => ', Royal Borough of Greenwich, London, Greater London, England',
    };
}

=head2 pin_colour

Greenwich uses the following pin colours:

=over 4

=item * grey: 'not responsible'

=item * green: fixed or closed

=item * red: confirmed

=item * yellow: any other open state (e.g. 'action scheduled' or 'in progress')

=back

=cut

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'grey' if $p->state eq 'not responsible';
    return 'green' if $p->is_fixed || $p->is_closed;
    return 'red' if $p->state eq 'confirmed';
    return 'yellow';
}

=head2 open311_extra_data_include

When sending reports via Open311, we include an C<external_id> attribute, set
to the report ID, and a C<closest_address> attribute set to the already
looked-up closest address.

=cut

sub open311_extra_data_include {
    my ($self, $row, $h) = @_;

    # Greenwich doesn't have category metadata to fill this
    my $open311_only = [
        { name => 'external_id', value => $row->id },
    ];

    if (my $address = $row->nearest_address) {
        push @$open311_only, (
            { name => 'closest_address', value => $address }
        );
        $h->{closest_address} = '';
    }

    return $open311_only;
}

=head2 open311_contact_meta_override

When fetching services via Open311, make sure some fields are set to
C<server_set> (they are not asked of the user, but set by the server).

=cut

sub open311_contact_meta_override {
    my ($self, $service, $contact, $meta) = @_;

    my %server_set = (easting => 1, northing => 1, closest_address => 1);
    foreach (@$meta) {
        $_->{automated} = 'server_set' if $server_set{$_->{code}};
    }
}

=head2 should_skip_sending_update

If an update was made on a report sent to the old Greenwich Open311 server,
skip trying to send that update.

=cut

sub should_skip_sending_update {
    my ($self, $update) = @_;

    my $contact = $update->problem->contact || return 0;
    my $endpoint = $contact->endpoint || return 0;
    return 1 if $endpoint eq 'https://open311.royalgreenwich.gov.uk/';
    return 0;
}

=head2 open311_update_missing_data

Lookup and include the USRN when sending reports, and also the UPRN
if we already have it from the nearest address.

=cut

sub open311_update_missing_data {
    my ($self, $row, $h, $contact) = @_;
    if (!$row->get_extra_field_value('usrn')) {
        if (my $usrn = $self->lookup_site_code($row, 'usrn')) {
            $row->update_extra_field({ name => 'usrn', value => $usrn });
        }
    }
    if (!$row->get_extra_field_value('uprn')) {
        if (my $uprn = $row->nearest_address_parts->{uprn}) {
            $row->update_extra_field({ name => 'uprn', value => $uprn });
        }
    }
}

1;
