=head1 NAME

FixMyStreet::Cobrand::Aberdeenshire - code specific to the Aberdeenshire cobrand

=head1 SYNOPSIS

We integrate with Aberdeenshire's Confirm back end.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Aberdeenshire;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

use JSON::MaybeXS;
use LWP::UserAgent;
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

sub council_area_id { '2648' }
sub council_area { 'Aberdeenshire' }
sub council_name { 'Aberdeenshire Council' }
sub council_url { 'aberdeenshire' }

=item * We do not show reports made before go-live on 2025-06-25.

=cut

sub cut_off_date { '2025-06-25' }

=item * Users with a Aberdeenshire.gov.uk email can always be found in the admin.

=cut

sub admin_user_domain { 'aberdeenshire.gov.uk' }

=item * Aberdeenshire use their own privacy policy, and their own contact form

=cut

sub privacy_policy_url { 'https://publications.aberdeenshire.gov.uk/acblobstorage/168aac73-5139-4622-a980-7a9436c3e0a3/cusersspellascdocumentsroads-pn.pdf' }

=item * Single sign on is enabled from the cobrand feature 'oidc_login'

=cut

sub social_auth_enabled {
    my $self = shift;

    return $self->feature('oidc_login') ? 1 : 0;
}

=item * Extract the user's details from the OIDC token

=cut

sub user_from_oidc {
    my ($self, $payload, $access_token) = @_;

    my $name = '';
    my $email = '';

    # Payload doesn't include user's name so fetch it from
    # the OIDC userinfo endpoint.
    my $cfg = $self->feature('oidc_login');
    if ($access_token && $cfg->{userinfo_uri}) {
        my $ua = LWP::UserAgent->new;
        my $response = $ua->get(
            $cfg->{userinfo_uri},
            Authorization => 'Bearer ' . $access_token,
        );
        my $user = decode_json($response->decoded_content);
        if ($user->{fname} && $user->{lname}) {
            $name = join(" ", $user->{fname}, $user->{lname});
        }
        if ($user->{emailaddress}) {
            $email = $user->{emailaddress};
        }
    }

    # In case we didn't get email from the claims above, default to value
    # present in payload. NB name is not available in this manner.
    $email ||= $payload->{sub} ? lc($payload->{sub}) : '';

    return ($name, $email);
}

sub abuse_reports_only { 1 }

=item * Users can not reopen reports

=cut

sub reopening_disallowed { 1 }

=item * We do not send questionnaires.

=cut

sub send_questionnaires { 0 }

=pod

=back

=cut

=head2 open311_update_missing_data

Unlike the ConfirmOpen311 role, we want to fetch a central asset ID here, not a
site code.

=cut

sub open311_update_missing_data {
    my ($self, $row, $h, $contact) = @_;

    # In case the client hasn't given us a site code, look up the
    # closest asset from the WFS service at the point we're sending the report
    if (!$row->get_extra_field_value('site_code')) {
        if (my $id = $self->lookup_site_code($row)) {
            $row->update_extra_field({ name => 'site_code', value => $id });
        }
    }

    # Q29 isn't shown to the user, but its default value depends on the category
    if ($contact->get_extra_field(code => 'Q29')  && !$row->get_extra_field_value('Q29')) {
        $row->update_extra_field({ name => 'Q29', value => ($contact->category eq 'Property/Vehicle Damage') ? 'YES' : 'NO' });
    }
}

=head2 open311_munge_update_params

We pass any category change.

=cut

sub open311_munge_update_params {
    my ( $self, $params, $comment ) = @_;

    my $p = $comment->problem;

    if ( $comment->text =~ /Category changed/ ) {
        my $service_code = $p->contact->email;
        $params->{service_code} = $service_code;
    }
}


=head2 open311_config

Send multiple photos as files to Open311

=cut

sub open311_config {
    my ($self, $row, $h, $params) = @_;

    $params->{multi_photos} = 1;
    $params->{upload_files} = 1;
}

=item * Make a few improvements to the display of geocoder results

Remove 'Aberdeenshire' and 'Alba / Scotland', skip any that don't mention Aberdeenshire at all

=cut

sub disambiguate_location {
    my $self = shift;
    my $string = shift;

    my $town = 'Aberdeenshire';

    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => $town,
        centre => '57.24185467,-2.62923456',
        span   => '0.95461349,2.03725374',
        bounds => [
            56.74712850, -3.80164643,
            57.70174199, -1.76439269,
        ],
        result_only_if => 'Aberdeenshire',
        result_strip => ', Aberdeenshire, Alba / Scotland',
    };
}

=head2 pin_colour

* Green if fixed or closed
* Orange if defect or in progress
* Red if open/confirmed

=cut

sub is_defect {
    my ($self, $p) = @_;
    return $p->user_id == $self->body->comment_user_id;
}

sub pin_colour {
    my ( $self, $p ) = @_;

    return 'green' if $p->is_fixed || $p->is_closed;

    return 'orange' if $self->is_defect($p)
        || $p->is_in_progress;

    # Confirmed/open
    return 'red';
}

sub lookup_site_code_config {
    my ($self, $property) = @_;

    # uncoverable subroutine
    # uncoverable statement
    my $host = FixMyStreet->config('STAGING_SITE') ? "tilma.staging.mysociety.org" : "tilma.mysociety.org";
    return {
        buffer => 1000, # metres
        url => "https://$host/mapserver/aberdeenshire",
        srsname => "urn:ogc:def:crs:EPSG::27700",
        typename => "WSS",
        property => "siteCode",
        accept_feature => sub { 1 }
    };
}

=head2 problems_restriction/problems_sql_restriction/problems_on_map_restriction

Reports made on FMS.com before the cut off date are not shown on the Aberdeenshire cobrand;
however if a report was fetched over Open311 it is shown regardless of the cut off date.

=cut

sub problems_restriction {
    my ($self, $rs) = @_;
    return $rs if FixMyStreet->staging_flag('skip_checks');

    $rs = $rs->to_body($self->body);

    my $date = $self->cut_off_date;
    my $table = ref $rs eq 'FixMyStreet::DB::ResultSet::Nearby' ? 'problem' : 'me';
    return $rs->search([
        { "$table.created" => { '>=', $date } },
        { "$table.service" => 'Open311' },
    ]);
}

sub problems_sql_restriction {
    my ($self, $item_table) = @_;
    my $date = $self->cut_off_date;
    if ($item_table ne 'comment') {
        return " AND ( created >= '$date' OR service = 'Open311' )";
    } else {
        return " AND created >= '$date'";
    }
}

sub problems_on_map_restriction {
    my ($self, $rs) = @_;
    my $date = $self->cut_off_date;
    my $table = ref $rs eq 'FixMyStreet::DB::ResultSet::Nearby' ? 'problem' : 'me';
    return $rs->search([
        { "$table.created" => { '>=', $date } },
        { "$table.service" => 'Open311' },
    ]);
}

=head2 dashboard_export_problems_add_columns

Aberdeenshire include the external ID of reports in the CSV export

=cut

sub dashboard_export_problems_add_columns {
    my ($self, $csv) = @_;

    $csv->add_csv_columns(
        external_id => 'Confirm ID',
    );

    return if $csv->dbi;

    $csv->csv_extra_data(sub {
        my $report = shift;

        return {
            external_id => $report->external_id,
        };
    });
}

=head2 skip_alert_state_changed_to

Aberdeenshire don't want the state of the report to be shown in update emails.

=cut

sub skip_alert_state_changed_to { 1 }

=item * Map starts at zoom level 5, closer than default and not based on population density.

=cut

sub default_map_zoom { 5 }

1;
