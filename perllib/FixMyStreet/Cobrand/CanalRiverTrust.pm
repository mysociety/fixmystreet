=head1 NAME

FixMyStreet::Cobrand::CanalRiverTrust - code specific to the Canal & River Trust cobrand

=head1 SYNOPSIS

The Canal & River Trust is a charity looking after 2,000 miles of canals and
rivers, along with reservoirs and structures, in England and Wales.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::CanalRiverTrust;
use parent 'FixMyStreet::Cobrand::UK';

use strict;
use warnings;
use utf8;

sub council_name { 'Canal & River Trust' }
sub council_url { 'canalrivertrust' }
sub site_key { 'canalrivertrust' }
sub restriction { { cobrand => shift->moniker } }
sub hide_areas_on_reports { 1 }
sub suggest_duplicates { 1 }
sub all_reports_single_body { { name => 'Canal & River Trust' } }

=over 4

=item * It is not a council, so inherits from UK, not UKCouncils, but a number of functions are shared with what councils do

=cut

sub cut_off_date { '' }
sub problems_restriction { FixMyStreet::Cobrand::UKCouncils::problems_restriction($_[0], $_[1]) }
sub problems_on_map_restriction { $_[0]->problems_restriction($_[1]) }
sub problems_sql_restriction { FixMyStreet::Cobrand::UKCouncils::problems_sql_restriction($_[0], $_[1]) }
sub users_restriction { FixMyStreet::Cobrand::UKCouncils::users_restriction($_[0], $_[1]) }
sub updates_restriction { FixMyStreet::Cobrand::UKCouncils::updates_restriction($_[0], $_[1]) }
sub base_url { FixMyStreet::Cobrand::UKCouncils::base_url($_[0]) }
sub contact_name { FixMyStreet::Cobrand::UKCouncils::contact_name($_[0]) }
sub contact_email { FixMyStreet::Cobrand::UKCouncils::contact_email($_[0]) }
sub users_staff_admin { FixMyStreet::Cobrand::UKCouncils::users_staff_admin($_[0]) }
sub admin_allow_user { FixMyStreet::Cobrand::UKCouncils::admin_allow_user($_[0], $_[1]) }
sub open311_extra_data { FixMyStreet::Cobrand::UKCouncils::open311_extra_data($_[0], $_[1], $_[2]) }

sub enter_postcode_text { 'Enter a location, village, or postcode' }
sub report_a_problem_label { 'Report' }
sub example_places { ['Little Venice', 'Wincham', 'SK6 8HU'] }
sub admin_user_domain { 'canalrivertrust.org.uk' }
sub abuse_reports_only { 1 }
sub contact_extra_fields { [ 'display_name' ] }

=item * We do not send questionnaires.

=cut

sub send_questionnaires { 0 }

=item * Single sign on is enabled from the cobrand feature 'oidc_login'

=cut

sub social_auth_enabled {
    my $self = shift;

    return $self->feature('oidc_login') ? 1 : 0;
}

sub user_from_oidc {
    my ($self, $payload) = @_;

    # Extract the user's name and email address from the payload.
    my $name = $payload->{name};
    my $email = lc $payload->{email};

    return ($name, $email);
}

=item * Uses its own privacy policy

=cut

sub privacy_policy_url {
    'https://canalrivertrust.org.uk/the-publication-scheme/making-a-request-for-information/privacy-notice'
}

=item * Include all reports in duplicate spotting, not just open ones

=cut

sub around_nearby_filter {
    my ($self, $params) = @_;

    delete $params->{states};
}

sub fetch_area_children {
    my $self = shift;

    my $areas = FixMyStreet::MapIt::call('areas', $self->area_types_for_admin);
    $areas = {
        map { $_->{id} => $_ }
        grep { ($_->{country} || 'E') =~ /^[EW]$/ }
        values %$areas
    };
    return $areas;
}

=back

=head2 report_validation

Changes the default name error message.

=cut

=head2 new_report_title_field_hint / new_report_detail_field_hint

Canal-specific examples rather than the default pothole ones.

=cut

sub new_report_title_field_hint {
    "e.g. ‘Damage to bridge’ or ‘Broken paddle’"
}

sub new_report_detail_field_hint {
    "e.g. ‘Paddle is not working and is making the lock very difficult to operate’"
}

sub report_validation {
    my ($self, $report, $errors) = @_;

    $errors->{name}
        = 'Please enter your full name. If you do not wish your name to be shown on the site, untick the box below.'
        if $errors->{name};
}

=head2 Report categories

There is special handling of body/contacts; categories must end "(CRT)"
(this is stripped for display).

=cut

sub munge_report_new_bodies {
    my ($self, $bodies) = @_;
    # On the cobrand there is only the Canals body
    %$bodies = map { $_->id => $_ } grep { $_->get_column('name') eq 'Canal & River Trust' } values %$bodies;
}

sub munge_report_new_contacts {
    my ($self, $contacts) = @_;

    foreach my $c (@$contacts) {
        my $clean_name = $c->category_display;
        # NOTE This is not actually saved to the DB
        $c->set_extra_metadata(display_name => $clean_name);
    }
}

sub category_display_name {
    my ( $self, $name ) = @_;
    $name =~ s/ \(CRT:.*?\)//;
    return $name;
}

sub admin_contact_validate_category {
    my ( $self, $category ) = @_;
    return $category =~ /\(CRT: \w.*?\)/ ? "" : "Category must end with (CRT: <group_name>).";
}

sub open311_extra_data_include {
    my ($self, $row, $h) = @_;

    my $open311_only = [
        { name => 'report_url',
          value => $h->{url} },
        { name => 'title',
          value => $row->title },
        { name => 'description',
          value => $row->detail },
    ];

    return $open311_only;
}

# Populates region_c if for some reason it failed to be populated during
# report creation.
# TODO Do we want to set anything beyond region_c, which is not
# very specific?
sub open311_update_missing_data {
    my ($self, $row, $h, $contact ) = @_;

    return if $row->get_extra_field_value('region_c');

    my $feature = $self->lookup_site_code($row);
    my $region = $feature->{'ms:Canals'}{'ms:region'};

    $row->update_extra_field({
        name => 'region_c',
        description => 'Region',
        value => $region,
    }) if $region;
}

# Canal 'region'
sub lookup_site_code {
    my ( $self, $row ) = @_;

    # Easting, northing.
    my ( $e, $n ) = Utils::convert_latlon_to_en(
        $row->latitude,
        $row->longitude,
    );

    my $cfg = $self->lookup_site_code_config( $e, $n );

    my $ukc = FixMyStreet::Cobrand::UKCouncils->new;
    my $features = $ukc->_fetch_features( $cfg, $e, $n );

    return $self->_nearest_feature( $cfg, $e, $n, $features );
}

sub report_new_is_on_canal {
    my $self = shift;

    # Easting, northing.
    my ( $e, $n ) = Utils::convert_latlon_to_en(
        $self->{c}->stash->{latitude},
        $self->{c}->stash->{longitude},
    );

    # Same distance (nearest_radius) as in web/cobrands/canalrivertrust/assets.js
    my $cfg = $self->lookup_site_code_config( $e, $n, 20 );

    my $ukc = FixMyStreet::Cobrand::UKCouncils->new;
    my $features = $ukc->_fetch_features($cfg) || [];

    return @$features ? 1 : 0;
}

sub lookup_site_code_config {
    my ( $self, $e, $n, $metres ) = @_;

    $metres //= 1000;

    my $url
        = FixMyStreet->config('STAGING_SITE')
        ? 'https://tilma.staging.mysociety.org/mapserver/crt'
        : 'https://tilma.mysociety.org/mapserver/crt';

    return {
        url => $url,
        # _distanceToLine() function (called in _nearest_feature())
        # is designed for EPSG:27700
        srsname => 'urn:ogc:def:crs:EPSG::27700',
        typename => 'Canals',
        # By default, arbitrarily searches within 1 km radius
        # TODO Is this enough?
        filter => "<Filter><DWithin><PropertyName>geom</PropertyName><gml:Point><gml:coordinates>$e,$n</gml:coordinates></gml:Point><Distance units='m'>$metres</Distance></DWithin></Filter>",
        outputformat => 'GML3',
        accept_feature => sub { 1 },
    };
}

# Default _nearest_feature() code handles JSON, but we need to handle XML
# for Canals
sub _nearest_feature {
    my ( $self, $cfg, $e, $n, $features ) = @_;

    # We have a list of features, and we want to find the one closest to the
    # report location.
    my $chosen = {};
    my $nearest;

    my $ukc = FixMyStreet::Cobrand::UKCouncils->new;

    for my $feature ( @{ $features || [] } ) {
        # Should be a LineString
        my $geo = $feature->{'ms:Canals'}{'ms:msGeometry'}{'gml:LineString'};

        next unless $geo;

        # Chances are there is only one unique canal region nearby, but look
        # for nearest feature just in case
        my $coords = $geo->{'gml:posList'}{'content'};
        my @coords = split / /, $coords;

        # Similar to _nearest_feature in Buckinghamshire.pm
        for ( my $i=0; $i<@coords-2; $i+=2 ) {
            my $distance = $ukc->_distanceToLine($e, $n,
                [ $coords[$i], $coords[$i+1] ],
                [ $coords[$i+2], $coords[$i+3] ]
            );
            if ( !defined $nearest || $distance < $nearest ) {
                $chosen = $feature;
                $nearest = $distance;
            }
        }
    }

    return $chosen;
}

1;
