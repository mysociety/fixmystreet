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

use LWP::Simple;
use URI;
use Try::Tiny;
use JSON::MaybeXS;


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

=item * Users can not reopen reports

=cut

sub reopening_disallowed { 1 }

=item * Jobs from Confirm that are completed (marked as fixed or closed) are not displayed after 48 hours

=cut

sub report_age {
    return {
        closed => {
            job => '48 hours',
        },
        fixed => {
            job => '48 hours',
        },
    };
}

=item * We do not send questionnaires.

=cut

sub send_questionnaires { 0 }

=item * Don't show reports before the go-live date, 4th October 2023

=cut

sub cut_off_date { '2023-10-04' }

=item * Add display_name as an extra contact field

=cut

sub contact_extra_fields { [ 'display_name' ] }

=item * Custom label and hint for new report detail field

=cut

sub new_report_detail_field_label {
    'Where is the location of the problem? Please be specific and identify the nearest property address or landmark to the problem.'
}

sub new_report_detail_field_hint {
    "e.g. 'The drain outside number 42 is blocked'"
}

=pod

=back

=cut

=head2 open311_skip_report_fetch

Do not fetch reports from Confirm for categories that are marked private.

=cut

sub open311_skip_report_fetch {
    my ( $self, $problem ) = @_;

    return 1 if $problem->non_public;
}

=head2 open311_update_missing_data

Unlike the ConfirmOpen311 role, we want to fetch a central asset ID here, not a
site code.

=cut

sub open311_update_missing_data {
    my ($self, $row, $h, $contact) = @_;

    # In case the client hasn't given us a central asset ID, look up the
    # closest asset from the WFS service at the point we're sending the report
    if (!$row->get_extra_field_value('central_asset_id')) {
        if (my $id = $self->lookup_site_code($row)) {
            $row->update_extra_field({ name => 'central_asset_id', value => $id });
        }
    }
}

sub lookup_site_code_config {
    my $host = FixMyStreet->config('STAGING_SITE') ? "tilma.staging.mysociety.org" : "tilma.mysociety.org";
    return {
        buffer => 200, # metres
        url => "https://$host/mapserver/gloucestershire",
        srsname => "urn:ogc:def:crs:EPSG::27700",
        typename => "WSF",
        property => "CentralAssetId",
        accept_feature => sub { 1 }
    };
}

=head2 open311_extra_data_include

Gloucestershire want report title to be in description field, along with
subcategory text, which is not otherwise captured by Confirm. Report detail
goes into the location field.
Subcategory text may need to be fetched from '_wrapped_service_code'
extra data.

=cut

around open311_extra_data_include => sub {
    my ( $orig, $self, $row, $h ) = @_;
    my $open311_only = $self->$orig( $row, $h );

    my $category = $row->category;
    my $wrapped_for_report
        = $row->get_extra_field_value('_wrapped_service_code');
    my $wrapped_categories
        = $row->contact->get_extra_field( code => '_wrapped_service_code' );

    if ( $wrapped_for_report && $wrapped_categories ) {
        ($category)
            = grep { $_->{key} eq $wrapped_for_report }
            @{ $wrapped_categories->{values} };

        $category = $category->{name};
    }

    push @$open311_only, {
        name  => 'description',
        value => $category . ' | ' . $row->title,
    };
    push @$open311_only, {
        name  => 'location',
        value => $row->detail,
    };

    return $open311_only;
};


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
        result_strip => ', Gloucestershire, England',
    };
}

=head2 is_defect

Returns true if it's a fetched job from Confirm.

=cut

sub is_defect {
    my ($self, $p) = @_;
    return $p->external_id && $p->external_id =~ /^JOB_/;
}

=head2 pin_colour

Green for anything completed or closed, yellow for the rest,
apart from defects which are blue.

=cut

sub pin_colour {
    my ( $self, $p ) = @_;

    return 'blue-work' if $self->is_defect($p);
    return 'green-tick' if $p->is_fixed || $p->is_closed;
    return 'yellow-cone';
}

sub path_to_pin_icons { '/i/pins/whole-shadow-cone-spot/' }

=head2 open311_config

Send multiple photos as files to Open311

=cut

sub open311_config {
    my ($self, $row, $h, $params) = @_;

    $params->{multi_photos} = 1;
    $params->{upload_files} = 1;
}

1;
