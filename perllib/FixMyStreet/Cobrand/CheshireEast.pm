=head1 NAME

FixMyStreet::Cobrand::CheshireEast - code specific to the CheshireEast cobrand [incomplete]


=head1 SYNOPSIS

We integrate with CheshireEast's Confirm back end.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::CheshireEast;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

use Moo;
with 'FixMyStreet::Roles::ConfirmOpen311';
with 'FixMyStreet::Roles::ConfirmValidation';

=head2 Defaults

=over 4

=cut

sub council_area_id { 21069 }
sub council_area { 'Cheshire East' }
sub council_name { 'Cheshire East Council' }
sub council_url { 'cheshireeast' }

=item * We restrict use of the contact form to abuse reports only.

=cut

sub abuse_reports_only { 1 }

=item * Users with a cheshireeast.gov.uk email can always be found in the admin.

=cut

sub admin_user_domain { 'cheshireeast.gov.uk' }

=item * The default map zoom is set to 3.

=cut

=item * Map type is CheshireEast.

=cut

sub map_type { 'CheshireEast' }

sub default_map_zoom { 3 }

=item * Fetched report description is not shown.

=cut

sub filter_report_description { "" }

=item * Uses custom text for the title field for new reports.

=cut

sub new_report_title_field_label {
    "Location of the problem"
}

sub new_report_title_field_hint {
    "Exact location, including any landmarks"
}

=item * /around map shows only open reports by default.

=cut

sub on_map_default_status { 'open' }

=item * We do not send questionnaires.

=cut

sub send_questionnaires { 0 }

=pod

=back

=cut

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'grey' if $p->state eq 'not responsible' || ($context ne 'reports' && !$self->owns_problem($p));
    return 'green' if $p->is_fixed || $p->is_closed;
    return 'yellow' if $p->is_in_progress;
    return 'red';
}

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        centre => '53.180415,-2.349354',
        bounds => [ 52.947150, -2.752929, 53.387445, -1.974789 ],
        result_only_if => 'Cheshire East',
        result_strip => ', Cheshire East, North West England, England',
    };
}

sub enter_postcode_text {
    'Enter a postcode, or a road and place name';
}

=head2 lookup_site_code_config

If the client does not send us a nearest street, we try and look one up in
Cheshire East's WFS server, for including in the data sent to Confirm.

=cut

sub lookup_site_code_config { {
    buffer => 200, # metres
    url => "https://maps.cheshireeast.gov.uk/geoserver/CEFixMyStreet/wfs",
    srsname => "urn:ogc:def:crs:EPSG::27700",
    typename => "TN_S_CODAdoptedStreetSections_LINE_CURRENT",
    property => "site_code",
    outputformat => 'application/json',
    accept_feature => sub { 1 }
} }

sub council_rss_alert_options {
    my $self = shift;
    my $all_areas = shift;
    my $c = shift;

    my %councils = map { $_ => 1 } @{$self->area_types};

    my @options;

    my $body = $self->body;

    my ($council, $ward);
    foreach (values %$all_areas) {
        if ($_->{type} eq 'UTA') {
            $council = $_;
            $council->{id} = $body->id; # Want to use body ID, not MapIt area ID
            $council->{short_name} = $self->short_name( $council );
            ( $council->{id_name} = $council->{short_name} ) =~ tr/+/_/;
        } else {
            $ward = $_;
            $ward->{short_name} = $self->short_name( $ward );
            ( $ward->{id_name} = $ward->{short_name} ) =~ tr/+/_/;
        }
    }

    push @options, {
        type      => 'council',
        id        => sprintf( 'council:%s:%s', $council->{id}, $council->{id_name} ),
        text      => 'All reported problems within the council',
        rss_text  => sprintf( 'RSS feed of problems within %s', $council->{name}),
        uri       => $c->uri_for( '/rss/reports/' . $council->{short_name} ),
    };
    push @options, {
        type     => 'ward',
        id       => sprintf( 'ward:%s:%s:%s:%s', $council->{id}, $ward->{id}, $council->{id_name}, $ward->{id_name} ),
        rss_text => sprintf( 'RSS feed of reported problems within %s ward', $ward->{name}),
        text     => sprintf( 'Reported problems within %s ward', $ward->{name}),
        uri      => $c->uri_for( '/rss/reports/' . $council->{short_name} . '/' . $ward->{short_name} ),
    } if $ward;

    return ( \@options, undef );
}

=head2 open311_extra_data_include

For reports made by staff on behalf of another user, append the staff
user's email & name to the report description, and include closest_address.

=cut

around open311_extra_data_include => sub {
    my ($orig, $self, $row, $h) = @_;

    my $contributed_suffix;
    if (my $contributed_by = $row->get_extra_metadata("contributed_by")) {
        if (my $staff_user = $self->users->find({ id => $contributed_by })) {
            $contributed_suffix = "\n\n(this report was made by <" . $staff_user->email . "> (" . $staff_user->name .") on behalf of the user)";
        }
    }

    my $open311_only = $self->$orig($row, $h);
    if ($contributed_suffix) {
        foreach (@$open311_only) {
            if ($_->{name} eq 'description') {
                $_->{value} .= $contributed_suffix;
            }
        }
        $row->detail($row->detail . $contributed_suffix);
    }

    if (my $address = $row->nearest_address) {
        push @$open311_only, (
            { name => 'closest_address', value => $address }
        );
    }

    return $open311_only;
};

1;
