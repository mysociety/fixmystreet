=head1 NAME

FixMyStreet::Cobrand::CentralBedfordshire - code specific to the Central Bedfordshire cobrand [incomplete]


=head1 SYNOPSIS

We integrate with Central Bedfordshire's Symology back end.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::CentralBedfordshire;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

=head2 Defaults

=over 4

=cut

sub council_area_id { 21070 }
sub council_area { 'Central Bedfordshire' }
sub council_name { 'Central Bedfordshire Council' }
sub council_url { 'centralbedfordshire' }

=item * Users with a centralbedfordshire.gov.uk email can always be found in the admin.

=cut

sub admin_user_domain { 'centralbedfordshire.gov.uk' }

=item * We do not show reports made before 2020-12-02.

=cut

# Don't show any reports made before the go-live date at all.
sub cut_off_date { '2020-12-02' }

=item * Uses custom text for the title field for new reports.

=cut

sub new_report_title_field_label {
    "Location of the problem"
}

sub new_report_title_field_hint {
    "Exact location, including any landmarks"
}

=item * We send an acknowledgement email when a report is sent; email includes the C<external_id> (Symology reference).

=cut

sub report_sent_confirmation_email { 'external_id' }

=item * We don't send report sent emails for Jadu backed contacts.

=cut

sub suppress_report_sent_email {
    my ($self, $report) = @_;
    foreach my $contact ($report->contacts) {
        return 1 if $contact->email =~ /Jadu/;
    }
    return 0;
}

=item * We don't send report author alerts for Jadu backed contacts.

=cut

sub suppress_reporter_alerts {
    my ($self, $report) = @_;
    foreach my $contact ($report->contacts) {
        return 1 if $contact->email =~ /Jadu/;
    }
    return 0;
}

=item * We do not send questionnaires.

=cut

sub send_questionnaires { 0 }

=pod

=back

=cut

=head2 pin_colour

Central Bedfordshire uses the following pin colours:

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

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    my $town = "Bedfordshire";

    return {
        %{ $self->SUPER::disambiguate_location() },
        town => $town,
        centre => '52.006697,-0.436005',
        bounds => [ 51.805087, -0.702181, 52.190913, -0.143957 ],
    };
}

sub enter_postcode_text { 'Enter a postcode, street name and area, or check an existing report number' }

sub open311_config {
    my ($self, $row, $h, $params, $contact) = @_;
    $params->{multi_photos} = 1;
    if ($contact->email =~ /Jadu/) {
        $params->{upload_files} = 1;
    }
}

sub open311_munge_update_params {
    my ($self, $params, $comment, $body) = @_;

    # TODO: This is the same as Bexley - could be factored into its own Role.
    $params->{service_request_id_ext} = $comment->problem->id;

    my $contact = $comment->problem->contact;
    $params->{service_code} = $contact->email;
}

=head2 should_skip_sending_update

Do not try and send updates to the Jadu backend.

=cut

sub should_skip_sending_update {
    my ($self, $update) = @_;

    my $code = $update->problem->contact->email;
    return 1 if $code =~ /^Jadu/;
    return 0;
}

sub lookup_site_code_config {
    my ($self, $property) = @_;

    # uncoverable subroutine
    # uncoverable statement
    {
        buffer => 1000, # metres
        url => "https://tilma.mysociety.org/mapserver/centralbeds",
        srsname => "urn:ogc:def:crs:EPSG::27700",
        typename => "Highways",
        property => $property,
        accept_feature => sub {
            # Sometimes the nearest feature has a NULL streetref1 property
            # but there is an overlapping feature that correctly has a streetref1
            # value a very small distance away. To avoid choosing the feature
            # with an empty streetref1 we reject those features, forcing selection
            # of the nearest feature that has a valid value.
            my $f = shift;
            return $f->{properties} && $f->{properties}->{$property};
        }
    }
}

sub open311_update_missing_data {
    my ($self, $row, $h, $contact) = @_;

    return if $contact->email =~ /Jadu/;

    # Reports made via the app probably won't have a NSGRef because we don't
    # display the road layer. Instead we'll look up the closest asset from the
    # WFS service at the point we're sending the report over Open311.
    if (!$row->get_extra_field_value('NSGRef')) {
        if (my $ref = $self->lookup_site_code($row, 'streetref1')) {
            $row->update_extra_field({ name => 'NSGRef', description => 'NSG Ref', value => $ref });
        }
    }
}

sub open311_extra_data_include {
    my ($self, $row, $h, $contact) = @_;

    if (my $id = $row->get_extra_field_value('UnitID')) {
        $row->detail($row->detail . "\n\nUnit ID: $id");
    }

    my $open311_only = [
        { name => 'title',
          value => $row->title },
        { name => 'description',
          value => $row->detail },
        { name => 'report_url',
          value => $h->{url} },
    ];

    if ($contact->email =~ /Jadu/) {
        my $contributed_by = $row->get_extra_metadata('contributed_by');

        my $reported_by_staff;
        if ($contributed_by) {
            $reported_by_staff = 'Yes';
            if (my $staff_user = $self->users->find({ id => $contributed_by })) {
                push @$open311_only, { name => 'staff_reporter', value => $staff_user->name };
            }
        } else {
            $reported_by_staff = 'No';
        }
        push @$open311_only, { name => 'reported_by_staff', value => $reported_by_staff };
        return $open311_only;
    }

    if (my $cfg = $self->feature('area_code_mapping')) {;
        my @areas = split ',', $row->areas;
        my @matches = grep { $_ } map { $cfg->{$_} } @areas;
        if (@matches) {
            push @$open311_only, { name => 'area_code', value => $matches[0] };
        }
    }

    return $open311_only;
}

# Currently, Central Beds does not handle the Unit ID being passed through for
# Trees; this will need adjusting if a new asset layer is added for which it
# does want to receive this.
sub open311_extra_data_exclude {
    [ 'UnitID' ]
}

sub open311_post_send {
    my ($self, $row, $h) = @_;

    # No post send needed for Jadu backed categories.
    return if $row->external_id && $row->external_id =~ /Jadu/;

    # Check Open311 was successful
    return unless $row->external_id;

    # For certain categories, send an email also
    my $emails = $self->feature('open311_email');
    my $dest = $emails->{$row->category};
    return unless $dest;

    my $sender = FixMyStreet::SendReport::Email->new( to => [ [ $dest, "Central Bedfordshire" ] ] );
    $sender->send($row, $h);
}

sub front_stats_show_middle { 'completed' }

sub dashboard_export_problems_add_columns {
    my ($self, $csv) = @_;

    $csv->add_csv_columns(
        external_id => 'CRNo',
        flytipping_types => 'Fly-tipping types',
    );

    $csv->csv_extra_data(sub {
        my $report = shift;

        my $types = $csv->_extra_field($report, 'Type') || $csv->_extra_field($report, 'type_of_waste') || [];
        $types = [$types] unless ref $types;
        $types = join(';', sort @$types);

        my $data = {
            flytipping_types => $types,
        };

        unless ($csv->dbi) {
            $data->{external_id} = $report->external_id;
        }

        return $data;
    });
}

1;
