=head1 NAME

FixMyStreet::Cobrand::Shropshire - code specific to the Shropshire cobrand

=head1 SYNOPSIS

Shropshire is a unitary authority, and we integrate with their Confirm back end.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Shropshire;
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

sub council_area_id { return 2238; } # https://mapit.mysociety.org/area/2238.html
sub council_area { return 'Shropshire'; }
sub council_name { return 'Shropshire Council'; }
sub council_url { return 'shropshire'; }

=item * Users with a shropshire.gov.uk email can always be found in the admin.

=cut

sub admin_user_domain {
    'shropshire.gov.uk'
}

=item * The default map zoom is set to 6.

=cut

sub default_map_zoom { 6 }

=item * We do not send questionnaires.

=cut

sub send_questionnaires { 0 }

=item * Add display_name as an extra contact field

=cut

sub contact_extra_fields { [ 'display_name' ] }

=item * We restrict use of the contact form to abuse reports only.

=back

=cut

sub abuse_reports_only { 1 }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        centre => '52.6354074681479,-2.73414274873688',
        span   => '0.692130766645555,1.00264228991404',
        bounds => [ 52.3062638566609, -3.23554076944319, 52.9983946233065, -2.23289847952914 ],
        result_strip => ', Shropshire, England',
    };
}

=head2 lookup_site_code_config

We store Shropshire's street gazetteer in our Tilma, which is used to look
up the nearest road to the report for including in the data sent to
Confirm.

=cut

sub lookup_site_code_config { {
    buffer => 200, # metres
    url => "https://tilma.mysociety.org/mapserver/shropshire",
    srsname => "urn:ogc:def:crs:EPSG::27700",
    typename => "Street_Gazetteer",
    property => "USRN",
    accept_feature => sub { 1 }
} }

=head2 staff_ignore_form_disable_form

Categories and extra question answers that would disable the form do not
apply to Shropshire staff, who can continue to make reports.

=cut

sub staff_ignore_form_disable_form {
    my $self = shift;
    my $c = $self->{c};

    return $c->user_exists
        && $c->user->belongs_to_body( $self->body->id );
}

=head2 open311_contact_meta_override

One field we pull from Confirm is for an 'Abandoned since' date. We want
this to be entered as a date, and for it to be required, so override what
we receive from open311-adapter for this field.

=cut

sub open311_contact_meta_override {
    my ($self, $service, $contact, $meta) = @_;
    for my $meta_data (@$meta) {
        if ($meta_data->{'description'} && $meta_data->{'description'} =~ 'Abandoned since') {
            $meta_data->{'fieldtype'} = 'date';
            $meta_data->{'required'} = 'true';
            last;
        }
    }
}

=head2 open311_config

Our Confirm integration can handle multiple photos and the direct uploading
of private photos, so we set those two parameter flags.

=cut

sub open311_config {
    my ($self, $row, $h, $params, $contact) = @_;

    $params->{multi_photos} = 1;
    $params->{upload_files} = 1;
}

=head2 open311_extra_data_include

Adds extra information to certain fields passed to Open311.

=cut

around open311_extra_data_include => sub {
    my ($orig, $self, $row, $h) = @_;

    my $open311_only = $self->$orig($row, $h);

    my $contributed_by = $row->get_extra_metadata('contributed_by');
    my $contributing_user = FixMyStreet::DB->resultset('User')->find({ id => $contributed_by });
    if ($contributing_user) {
        push @$open311_only, { name => 'contributed_by', value => 1 };
    }

    if (!$row->used_map) {
        for (@$open311_only) {
            if ($_->{name} eq 'description') {
                my $search_string
                    = $row->postcode
                    ? 'Search string used: ' . $row->postcode . "\n"
                    : '';

                my $prefix =<<"HERE";
NOTE:
Map was not used; location may not be accurate.
$search_string
HERE
                $_->{value} = $prefix . $_->{value};
            }
        }
    }

    return $open311_only;
};

sub dashboard_export_problems_add_columns {
    my ($self, $csv) = @_;

    $csv->add_csv_columns(
        private_report => 'Private',
        alerts_count => "Subscribers",
    );

    my $alerts_lookup = $csv->dbi ? undef : $self->csv_update_alerts;

    $csv->csv_extra_data(sub {
        my $report = shift;

        my $non_public = $csv->dbi ? $report->{non_public} : $report->non_public;
        if ($alerts_lookup) {
            return {
                alerts_count => ($alerts_lookup->{$report->id} || 0),
                private_report => $non_public ? 'Yes' : 'No'
            };
        } else {
            return {
                alerts_count => ($report->{alerts_count} || 0),
                private_report => $non_public ? 'Yes' : 'No'
            }
        }
    });
}

=head2 pin_colour

Green for completed or closed, yellow for open,
blue for anything else (in progress, action scheduled, etc)

=cut

sub pin_colour {
    my ( $self, $p ) = @_;

    return 'green-tick' if $p->is_fixed || $p->is_closed;
    return 'yellow-cone' if $p->state eq 'confirmed';
    return 'blue-work';
}

sub path_to_pin_icons { '/i/pins/whole-shadow-cone-spot/' }

1;
