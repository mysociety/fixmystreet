=head1 NAME

FixMyStreet::Cobrand::Camden - code specific to the Camden cobrand

=head1 SYNOPSIS

Camden is a London borough using FMS with a Symology integration

=cut


package FixMyStreet::Cobrand::Camden;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

sub council_area_id { return [2505, 2488]; }
sub council_area { return 'Camden'; }
sub council_name { return 'Camden Council'; }
sub council_url { return 'camden'; }
sub get_geocoder { 'OSM' }
sub cut_off_date { '2023-02-01' }

sub enter_postcode_text { 'Enter a Camden postcode or street name' }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    my $town = 'Camden';

    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => $town,
        centre => '51.546390811297,-0.157422262955539',
        span   => '0.0603011959324533,0.108195286339115',
        bounds => [ 51.5126591342049, -0.213511484504216, 51.5729603301373, -0.105316198165101 ],
    };
}

sub new_report_title_field_label {
    "Location of the problem"
}

sub new_report_title_field_hint {
    "e.g. outside no.18, or near postbox"
}

sub send_questionnaires {
    return 0;
}

sub privacy_policy_url {
    'https://www.camden.gov.uk/data-protection-privacy-and-cookies'
}

sub admin_user_domain { 'camden.gov.uk' }

sub lookup_site_code_config {
    my ($self, $property) = @_;

    # uncoverable subroutine
    # uncoverable statement
    {
        buffer => 1000, # metres
        url => "https://tilma.mysociety.org/mapserver/camden",
        srsname => "urn:ogc:def:crs:EPSG::27700",
        typename => "Streets",
        property => $property,
        accept_feature => sub { 1 },
    }
}

sub open311_extra_data_include {
    my ($self, $row, $h, $contact) = @_;

    # Reports made via the app probably won't have a NSGRef because we don't
    # display the road layer. Instead we'll look up the closest asset from the
    # WFS service at the point we're sending the report over Open311.
    if (!$row->get_extra_field_value('NSGRef')) {
        if (my $ref = $self->lookup_site_code($row, 'NSG_REF')) {
            $row->update_extra_field({ name => 'NSGRef', description => 'NSG Ref', value => $ref });
        }
    }

    return [];
}

sub open311_config {
    my ($self, $row, $h, $params, $contact) = @_;
    $params->{multi_photos} = 1;
}

sub open311_munge_update_params {
    my ($self, $params, $comment, $body) = @_;
    $params->{service_request_id_ext} = $comment->problem->id;

    my $contact = $comment->problem->contact;
    $params->{service_code} = $contact->email;
}

=head2 categories_restriction

Camden don't want TfL's River Piers categories on their cobrand.

=cut

sub categories_restriction {
    my ($self, $rs) = @_;

    return $rs->search( { 'me.category' => { -not_like => 'River Piers%' } } );
}

# Problems and comments are always treated as anonymous so the user's name isn't displayed.
sub is_problem_anonymous { 1 }

sub is_comment_anonymous { 1 }

sub social_auth_enabled {
    my $self = shift;

    return $self->feature('oidc_login') ? 1 : 0;
}

sub user_from_oidc {
    my ($self, $payload) = @_;

    # Extract the user's name and email address from the payload.
    my $name = $payload->{name};
    my $email = $payload->{preferred_username};

    return ($name, $email);
}

=head2 check_report_is_on_cobrand_asset

If the location is covered by an area of differing responsibility (e.g. Brent
in Camden, or Camden in Brent), return true (either 1 if an area name is
provided, or the name of the area if not). Identical to function in Brent.pm

=cut

sub check_report_is_on_cobrand_asset {
    my ($self, $council_area) = shift @_;

    my $lat = $self->{c}->stash->{latitude};
    my $lon = $self->{c}->stash->{longitude};
    my ($x, $y) = Utils::convert_latlon_to_en($lat, $lon, 'G');
    my $host = FixMyStreet->config('STAGING_SITE') ? "tilma.staging.mysociety.org" : "tilma.mysociety.org";

    my $cfg = {
        url => "https://$host/mapserver/brent",
        srsname => "urn:ogc:def:crs:EPSG::27700",
        typename => "BrentDiffs",
        filter => "<Filter><Contains><PropertyName>Geometry</PropertyName><gml:Point><gml:coordinates>$x,$y</gml:coordinates></gml:Point></Contains></Filter>",
        outputformat => 'GML3',
    };

    my $features = $self->_fetch_features($cfg, $x, $y, 1);

    if ($$features[0]) {
        if ($council_area) {
            if ($$features[0]->{'ms:BrentDiffs'}->{'ms:name'} eq $council_area) {
                return 1;
            }
        } else {
            return $$features[0]->{'ms:BrentDiffs'}->{'ms:name'};
        }
    }
}

=head2 munge_overlapping_asset_bodies

Alters the list of available bodies for the location,
depending on calculated responsibility. Here, we remove the
Brent body if we're inside Camden and it's not a Brent area.

=cut

sub munge_overlapping_asset_bodies {
    my ($self, $bodies) = @_;

    # in_area will be true if the point is within the administrative area of Camden
    my $in_area = scalar(%{$self->{c}->stash->{all_areas}}) == 1 && (values %{$self->{c}->stash->{all_areas}})[0]->{id} eq $self->council_area_id->[0];
    # cobrand will be true if the point is within an area of different responsibility from the norm
    my $cobrand = $self->check_report_is_on_cobrand_asset;
    if ($in_area && !$cobrand) {
        # Within Camden, and Camden's responsibility
        %$bodies = map { $_->id => $_ } grep {
            $_->name ne 'Brent Council'
            } values %$bodies;
    }
};

=head2 munge_cobrand_asset_categories

If we're in an overlapping area, we want to take the street categories
of one body, and the non-street categories of the other.

=cut

sub munge_cobrand_asset_categories {
    my ($self, $contacts) = @_;

    # in_area will be true if the point is within the administrative area of Camden
    my $in_area = scalar(%{$self->{c}->stash->{all_areas}}) == 1 && (values %{$self->{c}->stash->{all_areas}})[0]->{id} eq $self->council_area_id->[0];
    # cobrand will be true if the point is within an area of different responsibility from the norm
    my $cobrand = $self->check_report_is_on_cobrand_asset || '';

    my $brent = FixMyStreet::Cobrand::Brent->new();
    my %non_street = map { $_ => 1 } @{ $brent->_camden_non_street } ;
    my $brent_body = $brent->body;
    my $camden_body = $self->body;

    if ($in_area && $cobrand eq 'Brent') {
        # Within Camden, but Brent's responsibility
        # Remove the non-street contacts of Brent
        @$contacts = grep { !($_->email !~ /^Symology/ && $_->body_id == $brent_body->id) } @$contacts
            if $brent_body;
        # Remove the street contacts of Camden
        @$contacts = grep { !(!$non_street{$_->category} && $_->body_id == $camden_body->id) } @$contacts;
    } elsif (!$in_area && $cobrand eq 'Camden') {
        # Outside Camden, but Camden's responsibility
        # Remove the street contacts of Brent
        @$contacts = grep { !($_->email =~ /^Symology/ && $_->body_id == $brent_body->id) } @$contacts
            if $brent_body;
        # Remove the non-street contacts of Camden
        @$contacts = grep { !($non_street{$_->category} && $_->body_id == $camden_body->id) } @$contacts;
    }
}

=head2 dashboard_export_problems_add_columns

Has user name and email fields added to their csv export

=cut

sub dashboard_export_problems_add_columns {
    my ($self, $csv) = @_;

    $csv->add_csv_columns(
        user_name => 'User Name',
        user_email => 'User Email',
    );

    $csv->objects_attrs({
        '+columns' => ['user.email'],
        join => 'user',
    });

    $csv->csv_extra_data(sub {
        my $report = shift;

        return {
            user_name => $report->name || '',
            user_email => $report->user->email || '',
        };
    });
}

=head2 post_report_sent

Camden auto-closes its abandoned bike/scooter categories,
with an update with explanatory text added.

=cut

sub post_report_sent {
    my ($self, $problem) = @_;

    my $contact = $problem->contact;
    my %groups = map { $_ => 1 } @{ $contact->groups };

    if ($groups{'Hired e-bike or e-scooter'}) {
        $self->_post_report_sent_close($problem, 'report/new/close_bike.html');
    }
}

1;
