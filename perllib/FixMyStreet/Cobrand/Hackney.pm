=head1 NAME

FixMyStreet::Cobrand::Hackney - code specific to the Hackney cobrand

=head1 SYNOPSIS

Hackney is a London borough, using two Alloy intergrations plus email.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Hackney;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;
use DateTime::Format::W3CDTF;

use Moo;
with 'FixMyStreet::Roles::Open311Alloy';

use JSON::MaybeXS;
use URI::Escape;
use mySociety::EmailUtil qw(is_valid_email is_valid_email_list);

=head2 Defaults

=over 4

=cut

sub council_area_id { return 2508; }
sub council_area { return 'Hackney'; }
sub council_name { return 'Hackney Council'; }
sub council_url { return 'hackney'; }
sub send_questionnaires { 0 }

=item * Hackney include the time of updates in alert emails

=cut

sub include_time_in_update_alerts { 1 }

=item * 'Hackney' is used as default town in geocoder, and there is one override

=cut

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    my $town = 'Hackney';

    # Teale Street is on the boundary with Tower Hamlets and
    # shows the 'please use fixmystreet.com' message, but Hackney
    # do provide services on that road.
    ($string, $town) = ('E2 9AA', '') if $string =~ /^teale\s+st/i;

    return {
        %{ $self->SUPER::disambiguate_location() },
        string => $string,
        town   => $town,
        centre => '51.552267,-0.063316',
        bounds => [ 51.519814, -0.104511, 51.577784, -0.016527 ],
        result_only_if => 'Hackney',
        result_strip => ', London, Greater London, England|, London Borough of Hackney',
    };
}

=item * Ask the geocoder for full address details

=cut

sub geocoder_munge_query_params {
    my ($self, $params) = @_;

    $params->{addressdetails} = 1;
}

=item * Geocoder results are somewhat munged to display more cleanly

=cut

sub geocoder_munge_results {
    my ($self, $result) = @_;
    if (my $a = $result->{address}) {
        if ($a->{road} && $a->{suburb} && $a->{postcode}) {
            $result->{display_name} = "$a->{road}, $a->{suburb}, $a->{postcode}";
            return;
        }
    }
}

=item * Default map zoom level of 6

=cut

sub default_map_zoom { 6 }

=item * Users with a hackney.gov.uk email can always be found in the admin.

=cut

sub admin_user_domain { 'hackney.gov.uk' }

=item * Social auth (OIDC for staff login) is enabled if the config is present

=cut

sub social_auth_enabled {
    my $self = shift;

    return $self->feature('oidc_login') ? 1 : 0;
}

=item * A category change to or from an Email category is auto-resent

=cut

sub category_change_force_resend {
    my ($self, $old, $new) = @_;

    # Get the Open311 identifiers
    my $contacts = $self->{c}->stash->{contacts};
    ($old) = map { $_->send_method || '' } grep { $_->category eq $old } @$contacts;
    ($new) = map { $_->send_method || '' } grep { $_->category eq $new } @$contacts;
    return 1 if $new eq 'Email' || $old eq 'Email';
    return 0;
}

sub user_from_oidc {
    my ($self, $payload) = @_;

    my $name = $payload->{name};
    my $email = $payload->{email};

    return ($name, $email);
}

=item * If a category is marked as protected in the admin, prevent any changes at all

=cut

sub open311_skip_existing_contact {
    my ($self, $contact) = @_;

    # For Hackney we want the 'protected' flag to prevent any changes to this
    # contact at all.
    return $contact->get_extra_metadata("open311_protect") ? 1 : 0;
}

sub open311_filter_contacts_for_deletion {
    my ($self, $contacts) = @_;

    # Don't delete open311 protected contacts when importing
    return $contacts->search({
        -not => { extra => { '@>' => '{"open311_protect":1}' } }
    });
}

sub problem_is_within_area_type {
    my ($self, $problem, $type) = @_;
    my $layer_map = {
        park => "greenspaces:hackney_park",
        estate => "housing:lbh_estate",
    };
    my $layer = $layer_map->{$type};
    return unless $layer;

    my ($x, $y) = $problem->local_coords;

    my $cfg = {
        url => "https://map2.hackney.gov.uk/geoserver/wfs",
        srsname => "urn:ogc:def:crs:EPSG::27700",
        typename => $layer,
        outputformat => "json",
        filter => "<Filter xmlns:gml=\"http://www.opengis.net/gml\"><Intersects><PropertyName>geom</PropertyName><gml:Point srsName=\"27700\"><gml:coordinates>$x,$y</gml:coordinates></gml:Point></Intersects></Filter>",
    };

    my $features = $self->_fetch_features($cfg, $x, $y) || [];
    return scalar @$features ? 1 : 0;
}

=item * Certain categories have multiple emails for sending to depending on location within park/estate

=cut

sub get_body_sender {
    my ( $self, $body, $problem ) = @_;

    my $contact = $body->contacts->search( { category => $problem->category } )->first;

    if (my ($park, $estate, $other) = $self->_split_emails($contact->email)) {
        my $to = $other;
        if ($self->problem_is_within_area_type($problem, 'park')) {
            $to = $park;
        } elsif ($self->problem_is_within_area_type($problem, 'estate')) {
            $to = $estate;
        }
        $problem->set_extra_metadata(split_match => { $contact->email => $to });
        if (is_valid_email($to)) {
            return { method => 'Email', contact => $contact };
        }
    }
    return $self->SUPER::get_body_sender($body, $problem);
}

sub munge_sendreport_params {
    my ($self, $row, $h, $params) = @_;

    my $split_match = $row->get_extra_metadata('split_match') or return;
    $row->unset_extra_metadata('split_match');
    for my $recip (@{$params->{To}}) {
        my ($email, $name) = @$recip;
        $recip->[0] = $split_match->{$email} if $split_match->{$email};
    }
}

# Bit of a hack, doing it here, but soon after this point the flag
# from get_body_sender (above) will be erased by a re-fetch.
around open311_config => sub {
    my ($orig, $self, $row, $h, $open311, $contact) = @_;
    $self->$orig($row, $h, $open311, $contact);

    # Make sure contact 'email' set correctly for Open311
    if (my $split_match = $row->get_extra_metadata('split_match')) {
        my $code = $split_match->{$contact->email};
        $contact->email($code) if $code;
    }
};

=item * When sending via Open311, make sure closest address is included

=cut

sub open311_extra_data_include {
    my ($self, $row, $h, $contact) = @_;

    my $open311_only = [
        { name => 'report_url',
          value => $h->{url} },
        { name => 'description',
          value => $row->detail },
        { name => 'category',
          value => $row->category },
        { name => 'group',
          value => $row->get_extra_metadata('group', '') },
    ];

    my $title = $row->title;
    # Certain categories for the Alloy Environmental Services integration
    # have manually-created extra fields that should be appended to the
    # report title when submitted via Open311.
    # This fetches the field names from the COBRAND_FEATURES config, so
    # if they change in the future it doesn't require code changes to deploy.
    my $field_names = $self->feature('environment_extra_fields') || [];
    my %fields = map { $_ => 1 } @$field_names;
    if ($contact->email =~ /^Environment/) {
        for (@{ $row->get_extra_fields }) {
            if ($fields{$_->{name}}) {
                $title .= "\n\n" . $_->{description} . "\n" . $_->{value};
            }
        }
        push @$open311_only,
            { name => 'requested_datetime',
              value => DateTime::Format::W3CDTF->format_datetime($row->confirmed->set_nanosecond(0)) };
    }
    push @$open311_only, { name => 'title', value => $title };

    if (my $address = $row->nearest_address) {
        push @$open311_only, (
            { name => 'closest_address', value => $address }
        );
        $h->{closest_address} = '';
    }

    return $open311_only;
}

sub open311_munge_update_params {
    my ($self, $params, $comment, $body) = @_;

    my $contact = $comment->problem->contact;
    $params->{service_code} = $contact->email;
}

sub _split_emails {
    my ($self, $email) = @_;

    my $parts = join '\s*', qw(^ park : (.*?) ; estate : (.*?) ; other : (.*?) $);
    my $regex = qr/$parts/i;

    if (my ($park, $estate, $other) = $email =~ $regex) {
        return ($park, $estate, $other);
    }
    return ();
}

sub validate_contact_email {
    my ( $self, $email ) = @_;

    return 1 if is_valid_email_list($email);

    my @emails = grep { $_ } $self->_split_emails($email);
    return unless @emails;
    return 1 if is_valid_email_list(join(",", @emails));
}

=item * Report detail can be a maximum of 256 characters in length.

=cut

sub report_validation {
    my ($self, $report, $errors) = @_;

    if ( length( $report->detail ) > 256 ) {
        $errors->{detail} = sprintf( _('Reports are limited to %s characters in length. Please shorten your report'), 256 );
    }

    return $errors;
}

=item * Nearest address/postcode and extra details are included in their CSV export

=cut

sub dashboard_export_problems_add_columns {
    my ($self, $csv) = @_;

    $csv->add_csv_columns(
        nearest_address => 'Nearest address',
        nearest_address_postcode => 'Nearest postcode',
        extra_details => "Extra details",
    );

    $csv->csv_extra_data(sub {
        my $report = shift;

        my $address = '';
        my $postcode = '';
        if ($csv->dbi) {
            if ( $report->{geocode} ) {
                my $addr = FixMyStreet::Geocode::Address->new($report->{geocode});
                $address = $addr->summary;
                $postcode = $addr->parts->{postcode};
            }
        } else {
            if ( $report->geocode ) {
                $address = $report->nearest_address;
                $postcode = $report->nearest_address_parts->{postcode};
            }
        }

        return {
            nearest_address => $address,
            nearest_address_postcode => $postcode,
            extra_details => $csv->_extra_metadata($report, 'detailed_information') || '',
        };
    });
}

=back

=head2 update_email_shortlisted_user

When an update is left on a Hackney report, this hook will send an alert email
to the email address(es) that originally received the report.

=cut

sub update_email_shortlisted_user {
    my ($self, $update) = @_;
    my $c = $self->{c};
    my $cobrand = FixMyStreet::Cobrand::Hackney->new; # $self may be FMS
    return if !$update->problem->to_body_named('Hackney');
    my $sent_to = $update->problem->get_extra_metadata('sent_to') || [];
    if (@$sent_to) {
        my @to = map { [ $_, $cobrand->council_name ] } @$sent_to;
        $c->send_email('alert-update.txt', {
            additional_template_paths => [
                FixMyStreet->path_to( 'templates', 'email', 'hackney' ),
                FixMyStreet->path_to( 'templates', 'email', 'fixmystreet.com'),
            ],
            to => \@to,
            report => $update->problem,
            cobrand => $cobrand,
            problem_url => $cobrand->base_url . $update->problem->url,
            data => [ {
                item_photo => $update->photo,
                item_text => $update->text,
                item_name => $update->name,
                item_anonymous => $update->anonymous,
            } ],
        });
    }
}

1;
