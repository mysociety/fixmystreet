=head1 NAME

FixMyStreet::Cobrand::Bristol - code specific to the Bristol cobrand

=head1 SYNOPSIS

Bristol is a unitary authority, with its own Open311 server.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Bristol;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use Moo;
with 'FixMyStreet::Roles::Open311Alloy';
with 'FixMyStreet::Roles::Open311Multi';

use strict;
use warnings;

=head2 Defaults

=over 4

=cut

sub council_area_id {
    [
        2561,  # Bristol City Council
        2642,  # North Somerset Council
        2608,  # South Gloucestershire Council
    ]
}
sub council_area { return 'Bristol'; }
sub council_name { return 'Bristol City Council'; }
sub council_url { return 'bristol'; }

use constant ROADWORKS_CATEGORY => 'Inactive roadworks';

=item * Users with a bristol.gov.uk email can always be found in the admin.

=cut

sub admin_user_domain { 'bristol.gov.uk' }

=item * We do not send questionnaires.

=back

=cut

sub send_questionnaires { 0 }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    my $town = 'Bristol';

    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => $town,
        centre => '51.4526044866206,-2.7706173308649',
        span   => '0.202810508012753,0.60740886659825',
        bounds => [ 51.3415749466466, -3.11785543094126, 51.5443854546593, -2.51044656434301 ],
        result_strip => ', City of Bristol, West of England, England',
    };
}

=head2 pin_colour

Bristol uses the following pin colours:

=over 4

=item * grey: closed

=item * green: fixed

=item * yellow: newly open

=item * orange: any other open state

=back

=cut

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'grey-cross' if $p->is_closed;
    return 'green-tick' if $p->is_fixed;
    return 'yellow-cone' if $p->state eq 'confirmed';
    return 'orange-work'; # all the other `open_states` like "in progress"
}

sub path_to_pin_icons { '/i/pins/whole-shadow-cone-spot/' }

=head2 body_disallows_state_change

Determines whether state of a report can be updated, based on user and current
report state. Original reporter only.

=cut

sub body_disallows_state_change {
    my ( $self, $problem ) = @_;
    return !($self->{c}->user_exists && $self->{c}->user->id == $problem->user->id);
}

=head2 category_change_force_resend

If a report was sent to a backend, when the category
changes to a category that is email or a different backend
it will be resent.

If it was sent to an email and the category is changed to
a backend it will also be resent.

=cut

sub _contact_type {
    my $contact = shift;

    return 'Alloy' if $contact->email =~ /^Alloy-/;
    return 'Email' if ($_->send_method || '') eq 'Email';
    return 'Confirm';
}

sub category_change_force_resend {
    my ($self, $old, $new) = @_;

    # Get the Open311 identifiers
    my $contacts = $self->{c}->stash->{contacts};

    ($old) = map { _contact_type($_) } grep { $_->category eq $old } @$contacts;
    ($new) = map { _contact_type($_) } grep { $_->category eq $new } @$contacts;

    return 0 if $old eq 'Confirm' && $new eq 'Confirm';
    return 0 if $old eq 'Alloy' && $new eq 'Alloy';
    return 1;
}

sub dashboard_export_problems_add_columns {
    my ($self, $csv) = @_;

    $csv->add_csv_columns(
        (
            staff_role => 'Staff Role',
            SizeOfIssue => 'Flytipping size',
            external_id => 'External ID',
        )
    );

    my $user_lookup = $self->csv_staff_users;
    my $userroles = $self->csv_staff_roles($user_lookup);

    $csv->csv_extra_data(sub {
        my $report = shift;

        return { SizeOfIssue => $csv->_extra_field($report, 'SizeOfIssue') } if $csv->dbi; # Everything else covered already

        my $by = $csv->_extra_metadata($report, 'contributed_by');
        my $staff_role = '';
        if ($by) {
            $staff_role = join(',', @{$userroles->{$by} || []});
        }
        return {
            external_id => $report->external_id,
            staff_role => $staff_role,
            SizeOfIssue => $csv->_extra_field($report, 'SizeOfIssue'),
        };
    });
}


=head2 open311_config

Bristol's original endpoint requires an email address, so flag to always send one (with
a fallback if one not provided).

=cut

sub open311_config {
    my ($self, $row, $h, $params, $contact) = @_;

    $params->{always_send_email} = 1;
    $params->{multi_photos} = 1;
    $params->{upload_files} = 1;
    $params->{upload_files_for_updates} = 1;
}

sub open311_config_updates {
    my ($self, $params) = @_;
    $params->{multi_photos} = 1;
}

=head2 open311_filter_contacts_for_deletion

The default Open311 protection is to allow the category name/group to be
changed without being overwritten by the category name of its existing service
code. We protect all categories that are Open311 protected, which will have
been manually added, from being removed by the Open311 populate service list
script.

=cut

sub open311_filter_contacts_for_deletion {
    my ($self, $contacts) = @_;

    # Don't delete open311 protected contacts when importing
    return $contacts->search({
        -not => { extra => { '@>' => '{"open311_protect":1}' } }
    });
}

=head2 open311_update_missing_data

All reports sent to Alloy should have a USRN set so the street parent
can be found and the locality can be looked up as well.

The USRN may be set by the roads asset layer, but staff can report anywhere
so are not restricted to the road layer and anyone can be make reports on
specific Bristol owned properties that don't have a USRN

=cut

sub lookup_site_code_config {
    my $self = shift;
    my $host = FixMyStreet->config('STAGING_SITE') ? "tilma.staging.mysociety.org" : "tilma.mysociety.org";
    my %ignored = map { $_ => 1 } @{ $self->_ignored_usrns };
    return {
        buffer => 200, # metres
        url => "https://$host/proxy/bristol/wfs/",
        typename => "COD_LSG",
        property => "USRN",
        version => '2.0.0',
        srsname => "urn:ogc:def:crs:EPSG::27700",
        accept_feature => sub {
            my $feature = shift;
            my $usrn = $feature->{properties}->{USRN};
            return $ignored{$usrn} ? 0 : 1;
        },
        reversed_coordinates => 1,
    };
}

sub open311_update_missing_data {
    my ($self, $row, $h, $contact) = @_;

    if ($contact->email =~ /^Alloy-/) {
        my $stored_usrn = $row->get_extra_field_value('usrn');
        my %ignored = map { $_ => 1 } @{ $self->_ignored_usrns };

        # Look up USRN if it's empty or if it's in the ignored list
        if (!$stored_usrn || $ignored{$stored_usrn}) {
            if (my $usrn = $self->lookup_site_code($row)) {
                $row->update_extra_field({ name => 'usrn', value => $usrn });
            }
        }
    };
}

sub _ignored_usrns {
    # This is a list of all National Highways USRNs within Bristol that should
    # be ignored when looking up site codes for Alloy reports. Provided by
    # Bristol in FD-5607.
    return FixMyStreet::DB->resultset("Config")->get('bristol_ignored_usrns') || [];
}

around open311_extra_data_include => sub {
    my ($orig, $self) = (shift, shift);
    my $open311_only = $self->$orig(@_);

    my ($row, $h, $contact) = @_;

    # Add contributing user's roles to report title
    if (my $contributed_by = $row->get_extra_metadata('contributed_by')) {
        if (my $user = FixMyStreet::DB->resultset('User')->find({ id => $contributed_by })) {
            my $roles = join(',', map { $_->name } $user->roles->all);
            my $extra = $user->name;
            $extra .= " - $roles" if $roles;
            for (@$open311_only) {
                if ($_->{name} eq 'title') {
                    $_->{value} = "$extra\n\n$_->{value}";
                }
            }
        }
    }

    return $open311_only;
};

=head2 open311_contact_meta_override

We need to mark some of the attributes returned by Bristol's Open311 server
as hidden or server_set.

=cut

sub open311_contact_meta_override {
    my ($self, $service, $contact, $meta) = @_;

    my %server_set = (easting => 1, northing => 1);
    my %hidden_field = (usrn => 1, asset_id => 1);
    foreach (@$meta) {
        $_->{automated} = 'server_set' if $server_set{$_->{code}};
        $_->{automated} = 'hidden_field' if $hidden_field{$_->{code}};
    }
}

sub open311_post_send {
    my ($self, $row, $h) = @_;

    # Check Open311 was successful
    return unless $row->external_id;
    return if $row->get_extra_metadata('extra_email_sent');

    # For Flytipping with witness, send an email also
    my $witness = $row->get_extra_field_value('Witness') || 0;
    return unless $witness;

    my $emails = $self->feature('open311_email') or return;
    my $dest = $emails->{$row->category} or return;
    $dest = [ $dest, 'FixMyStreet' ];

    $row->push_extra_fields({ name => 'fixmystreet_id', description => 'FMS reference', value => $row->id });

    my $sender = FixMyStreet::SendReport::Email->new(
        use_verp => 0, use_replyto => 1, to => [ $dest ] );
    $sender->send($row, $h);
    if ($sender->success) {
        $row->set_extra_metadata(extra_email_sent => 1);
    }

    $row->remove_extra_field('fixmystreet_id');
}

=head2 post_report_sent

Bristol have a special Inactive roadworks category; any reports made in that
category are automatically closed, with an update with explanatory text added.

=cut

sub post_report_sent {
    my ($self, $problem) = @_;

    if ($problem->category eq ROADWORKS_CATEGORY) {
        $self->_post_report_sent_close($problem, 'report/new/roadworks_text.html');
    }
}

=head2 munge_overlapping_asset_bodies

Bristol take responsibility for some parks that are in North Somerset and South Gloucestershire.

To make this work, the Bristol body is setup to cover North Somerset and South Gloucestershire
as well as Bristol. Then method decides which body or bodies to use based on the passed in bodies
and whether the report is in a park.

=cut

sub munge_overlapping_asset_bodies {
    my ($self, $bodies) = @_;

    my $all_areas = $self->{c}->stash->{all_areas};

    if (grep ($self->council_area_id->[0] == $_, keys %$all_areas)) {
        # We are in the Bristol area so carry on as normal
        return;
    } elsif ($self->check_report_is_on_cobrand_asset) {
        # We are not in a Bristol area but the report is in a park that Bristol is responsible for,
        # so only show Bristol categories.
        %$bodies = map { $_->id => $_ } grep { $_->get_column('name') eq $self->council_name } values %$bodies;
    } else {
        # We are not in a Bristol area and the report is not in a park that Bristol is responsible for,
        # so only show other categories.
        %$bodies = map { $_->id => $_ } grep { $_->get_column('name') ne $self->council_name } values %$bodies;
    }
}

sub open311_munge_update_params {
}

sub check_report_is_on_cobrand_asset {
    my ($self) = @_;

    # We're only interested in these two parks that lie partially outside of Bristol.
    my @relevant_parks_site_codes = (
        'ASHTCOES', # Ashton Court Estate
        'STOKPAES', # Stoke Park Estate
        'LONGCP', # Long Ashton Park And Ride Car Park
    );

    my $park = $self->_park_for_point(
        $self->{c}->stash->{latitude},
        $self->{c}->stash->{longitude},
        'parks,CarParks',
    );
    return 0 unless $park;

    my $code;
    if ($park->{"ms:parks"}) {
        $code = $park->{"ms:parks"}->{"ms:SITE_CODE"};
    } elsif ($park->{"ms:CarParks"}) {
        $code = $park->{"ms:CarParks"}->{"ms:site_code"};
    }
    return grep { $_ eq $code } @relevant_parks_site_codes;
}

sub _park_for_point {
    my ( $self, $lat, $lon, $type ) = @_;

    my ($x, $y) = Utils::convert_latlon_to_en($lat, $lon, 'G');

    my $host = FixMyStreet->config('STAGING_SITE') ? "tilma.staging.mysociety.org" : "tilma.mysociety.org";
    my $filter = "<Filter><Contains><PropertyName>Geometry</PropertyName><gml:Point><gml:coordinates>$x,$y</gml:coordinates></gml:Point></Contains></Filter>";
    if (my $c = () = $type =~ /,/g) {
        $filter = "($filter)" x ($c+1);
    }
    my $cfg = {
        url => "https://$host/mapserver/bristol",
        srsname => "urn:ogc:def:crs:EPSG::27700",
        typename => $type,
        filter => $filter,
        outputformat => 'GML3',
    };

    my $features = $self->_fetch_features($cfg);
    my $park = $features->[0];

    return $park;
}

sub get_body_sender {
    my ( $self, $body, $problem ) = @_;

    my $emails = $self->feature('open311_email');
    if ($problem->category eq 'Flytipping' && $emails->{flytipping_parks}) {
        my $park = $self->_park_for_point(
            $problem->latitude,
            $problem->longitude,
            'flytippingparks',
        );
        if ($park) {
            $problem->set_extra_metadata('flytipping_email' => $emails->{flytipping_parks});
            return { method => 'Email' };
        }

    }
    return $self->SUPER::get_body_sender($body, $problem);
}

sub munge_sendreport_params {
    my ($self, $row, $h, $params) = @_;

    if ( my $email = $row->get_extra_metadata('flytipping_email') ) {
        $row->push_extra_fields({ name => 'fixmystreet_id', description => 'FMS reference', value => $row->id });

        my $to = [ [ $email, $self->council_name ] ];

        my $witness = $row->get_extra_field_value('Witness') || 0;
        if ($witness) {
            my $emails = $self->feature('open311_email');
            my $dest = $emails->{$row->category};
            push @$to, [ $dest, $self->council_name ];
        }

        $params->{To} = $to;
    }

    # Check if this is a Dott report made within Bristol
    # and change the destination email address if so.
    my @areas = split(",", $row->areas);
    my %ids = map { $_ => 1 } @areas;
    if ($row->category eq 'Abandoned Dott bike or scooter' && $ids{2561}) {
        if (my $email = $self->feature("dott_email")) {
            $params->{To}->[0]->[0] = $email;
        }
    }
}

1;
