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

=item * We do not send questionnaires.

=cut

sub send_questionnaires { 0 }

=item * Add display_name as an extra contact field

=cut

sub contact_extra_fields { [ 'display_name' ] }

=item * Custom label and hint for new report detail field

=cut

sub new_report_detail_field_label {
    'Where is the location of the problem, and can you give us a little more information?'
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
    };
}

# TODO What else to add here?
sub lookup_site_code_config {
    {
        buffer => 200, # metres
    }
}

=head2 pin_colour

Green for anything completed or closed, yellow for the rest.

=cut

sub pin_colour {
    my ( $self, $p ) = @_;

    return 'green' if $p->is_fixed || $p->is_closed;

    return 'yellow';
}

sub extra_around_pins {
    my ($self, $bbox) = @_;

    if (!defined($bbox)) {
        return [];
    }

    my $res = $self->pins_from_wfs($bbox);

    return $res;
}


# Get defects from WDM feed and display them on /around page.
sub pins_from_wfs {
    my ($self, $bbox) = @_;

    my $wfs = $self->defect_wfs_query($bbox);

    # Generate a negative fake ID so it doesn't clash with FMS report IDs.
    my $fake_id = -1;
    my @pins = map {
        my $coords = $_->{geometry}->{coordinates};
        my $props = $_->{properties};
        {
            id => $fake_id--,
            latitude => @$coords[1],
            longitude => @$coords[0],
            colour => 'defects',
            title => $props->{description},
        };
    } @{ $wfs->{features} };

    return \@pins;
}

sub defect_wfs_query {
    my ($self, $bbox) = @_;

    return if FixMyStreet->test_mode eq 'cypress';

    my $host = FixMyStreet->config('STAGING_SITE') ? "tilma.staging.mysociety.org" : "tilma.mysociety.org";
    my $uri = URI->new("https://$host/confirm.php");
    my $suffix = FixMyStreet->config('STAGING_SITE') ? "staging" : "assets";
    $uri->query_form(
        layer => 'jobs',
        url => "https://gloucestershire.$suffix",
        bbox => $bbox,
    );

    try {
        my $response = get($uri);
        my $json = JSON->new->utf8->allow_nonref;
        return $json->decode($response);
    } catch {
        # Ignore WFS errors.
        return {};
    };
}

sub path_to_pin_icons {
    return '/cobrands/oxfordshire/images/';
}

=head2 open311_config

Send multiple photos as files to Open311

=cut

sub open311_config {
    my ($self, $row, $h, $params) = @_;

    $params->{multi_photos} = 1;
    $params->{upload_files} = 1;
}

1;
