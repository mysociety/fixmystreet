=head1 NAME

FixMyStreet::Cobrand::Brent - code specific to the Brent cobrand

=head1 SYNOPSIS

Brent is a London borough using FMS and WasteWorks

=cut

package FixMyStreet::Cobrand::Brent;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;
use Moo;
use DateTime;

=head1 INTEGRATIONS

Integrates with Echo and Symology for FixMyStreet

Integrates with Echo for WasteWorks.

Uses SCP for accepting payments.

Uses OpenUSRN for locating nearest addresses on the Highway

=cut
with 'FixMyStreet::Roles::Open311Multi';
with 'FixMyStreet::Roles::CobrandOpenUSRN';
with 'FixMyStreet::Roles::CobrandEcho';

sub council_area_id { return 2488; }
sub council_area { return 'Brent'; }
sub council_name { return 'Brent Council'; }
sub council_url { return 'brent'; }

=head1 DESCRIPTION

=cut

=head2 FMS Defaults

=over 4

=cut

=item * Use their own brand colours for pins

=cut 

sub path_to_pin_icons {
    return '/cobrands/brent/images/';
}

=item * Users with a brent.gov.uk email can always be found in the admin.

=cut

sub admin_user_domain { 'brent.gov.uk' }

=item * Allows anonymous reporting

=cut 

sub allow_anonymous_reports { 'button' }

=item * Has a default map zoom of 6

=cut 

sub default_map_zoom { 6 }

=item * Uses their own privacy policy

=cut 

sub privacy_policy_url {
    'https://www.brent.gov.uk/the-council-and-democracy/access-to-information/data-protection-and-privacy/brent-privacy-policy'
}

=item * Uses the OSM geocoder

=cut

sub get_geocoder { 'OSM' }

=item * Doesn't allow the reopening of reports

=cut

sub reopening_disallowed { 1 }

=item * Uses slightly different text on the geocode form.

=cut

sub enter_postcode_text {
    my ($self) = @_;
    return 'Enter a ' . $self->council_area . ' postcode, or street name';
}

=item * Only returns search results from Brent

=cut

sub disambiguate_location { {
    centre => '51.5585509362304,-0.26781886445231',
    span   => '0.0727325098393763,0.144085171830317',
    bounds => [ 51.52763684136, -0.335577710963202, 51.6003693511994, -0.191492539132886 ],
    town => 'Brent',
} }

=item * Filters down search results to be the street name and the postcode only

=cut

sub geocoder_munge_results {
    my ($self, $result) = @_;

    $result->{display_name} =~ s/, London Borough of Brent, London, Greater London, England//;
}

=back

=cut

=head2 categories_restriction

Doesn't show TfL's River Piers category as no piers in Brent

=cut

sub categories_restriction {
    my ($self, $rs) = @_;

    return $rs->search( { 'me.category' => { '-not_like' => 'River Piers%' } } );
}

=head2 social_auth_enabled and user_from_oidc

=over 4

=cut

=item * Single sign on is enabled from the cobrand feature 'oidc_login'

=cut

sub social_auth_enabled {
    my $self = shift;

    return $self->feature('oidc_login') ? 1 : 0;
}

=item * Checks Brent specific fields for the single sign on name and email

=cut

sub user_from_oidc {
    my ($self, $payload) = @_;

    my $name = join(" ", $payload->{givenName}, $payload->{surname});
    my $email = $payload->{email};

    return ($name, $email);
}

=back

=cut

=head2 open311_config

Sends all photo urls in the Open311 data

=cut

sub open311_config {
    my ($self, $row, $h, $params) = @_;
    $params->{multi_photos} = 1;
}

=head2 open311_munge_update_params

Updates which are sent over Open311 have 'service_request_id_ext' set 
to the id of the update's report

=cut

sub open311_munge_update_params {
    my ($self, $params, $comment, $body) = @_;
    $params->{service_request_id_ext} = $comment->problem->id;
}

=head2 open311_extra_data_include

=over 4

=cut

sub open311_extra_data_include {
    my ($self, $row, $h, $contact) = @_;

=item * Adds NSGRef from WFS service as app doesn't include road layer for Symology

Reports made via the app probably won't have a NSGRef because we don't
display the road layer. Instead we'll look up the closest asset from the
WFS service at the point we're sending the report over Open311.

=cut

    my $open311_only;
    if ($contact->email =~ /^Symology/) {

        if (!$row->get_extra_field_value('NSGRef')) {
            if (my $ref = $self->lookup_site_code($row, 'usrn')) {
                $row->update_extra_field({ name => 'NSGRef', description => 'NSG Ref', value => $ref });
            }
        }

=item * Copies UnitID into the details field for the Drains and gullies category

=cut

        if ($contact->groups->[0] eq 'Drains and gullies') {
            if (my $id = $row->get_extra_field_value('UnitID')) {
                $self->{brent_original_detail} = $row->detail;
                my $detail = $row->detail . "\n\nukey: $id";
                $row->detail($detail);
            }
        }

=item * Adds NSGRef from WFS service as app doesn't include road layer for Echo

Same as Symology above, but different attribute name.

=cut

    } elsif ($contact->email =~ /^Echo/) {
        my $type = $contact->get_extra_metadata('type') || '';
        if ($type ne 'waste' && !$row->get_extra_field_value('usrn')) {
            if (my $ref = $self->lookup_site_code($row, 'usrn')) {
                $row->update_extra_field({ name => 'usrn', description => 'USRN', value => $ref });
            }
        }
    }

    push @$open311_only, { name => 'title', value => $row->title };
    push @$open311_only, { name => 'description', value => $row->detail };

    return $open311_only;
}

=back

=cut

=head2 open311_extra_data_exclude

Doesn't send UnitID for Drains and gullies category as an extra 
field in open311 data. It has been transferred to the details 
field by open311_extra_data_include

=cut

sub open311_extra_data_exclude {
    my ($self, $row, $h, $contact) = @_;

    return ['UnitID'] if $contact->groups->[0] eq 'Drains and gullies';
    return [];
}

=head2 open311_post_send

Restore the original detail field if it was changed by open311_extra_data_include 
to put the UnitID in the detail field for sending

=cut

sub open311_post_send {
    my ($self, $row) = @_;
    $row->detail($self->{brent_original_detail}) if $self->{brent_original_detail};
}

=head2 prevent_questionnaire_updating_status

Doesn't allow questionnaire responses to change the
status of reports

=cut

sub prevent_questionnaire_updating_status { 1 };

=head2 admin_templates_external_status_code_hook

Munges empty fields out of external status code used
for triggering template responses so non-waste
Echo status codes will trigger auto-templates

=cut

sub admin_templates_external_status_code_hook {
    my ($self) = @_;
    my $c = $self->{c};

    my $res_code = $c->get_param('resolution_code') || '';
    my $task_type = $c->get_param('task_type') || '';
    my $task_state = $c->get_param('task_state') || '';

    my $code = "$res_code,$task_type,$task_state";
    $code = '' if $code eq ',,';
    $code =~ s/,,$// if $code;

    return $code;
}

=head2 waste_event_state_map

State map for Echo states - not actually waste only as Echo
used for FMS integration for Brent

=cut

sub waste_event_state_map {
    return {
        New => { New => 'confirmed' },
        Pending => {
            Unallocated => 'action scheduled',
            Accepted => 'action scheduled',
            'Allocated to Crew' => 'in progress',
            'Allocated to EM' => 'investigating',
            'Replacement Bin Required' => 'action scheduled',
        },
        Closed => {
            Closed => 'fixed - council',
            Completed => 'fixed - council',
            'Not Completed' => 'unable to fix',
            'Partially Completed' => 'closed',
            'No Repair Required' => 'unable to fix',
        },
        Cancelled => {
            Rejected => 'closed',
        },
    };
}

1;
