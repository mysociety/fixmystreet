=head1 NAME

FixMyStreet::Cobrand::Southwark - code specific to the Southwark cobrand

=head1 SYNOPSIS

Southwark is a London borough, with a Confirm integration.

=head1 DESCRIPTION

=cut

package FixMyStreet::Cobrand::Southwark;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

use List::Util qw(any);
use Moo;

=head2 Defaults

=over 4

=cut

with 'FixMyStreet::Roles::ConfirmOpen311';
with 'FixMyStreet::Roles::ConfirmValidation';

sub council_area_id { 2491 }
sub council_area { 'Southwark' }
sub council_name { 'Southwark Council' }
sub council_url { 'southwark' }

=item * Don't show reports before the go-live date, 22nd March 2023

=cut

sub cut_off_date { '2023-03-22' }

=item * Users with a southwark.gov.uk email can always be found in the admin.

=cut

sub admin_user_domain { 'southwark.gov.uk' }

=item * We don't send questionnaires.

=cut

sub send_questionnaires { 0 }

=item * Allow anonymous reporting

=cut

sub allow_anonymous_reports { 'button' }

=item * Has a privacy policy on their own site

=cut

sub privacy_policy_url { 'https://www.southwark.gov.uk/council-and-democracy/freedom-of-information-and-data-protection/corporate-data-privacy-notice' }

=item * Add display_name as an extra contact field

=cut

sub contact_extra_fields { [ 'display_name' ] }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        town => "Southwark",
        centre => '51.4742389056488,-0.0740567820867757',
        span   => '0.0893021072823146,0.0821035484648614',
        bounds => [ 51.4206051986445, -0.111491915302168, 51.5099073059268, -0.029388366837307 ],
        result_strip => ', London Borough of Southwark, London, Greater London, England',
    };
}

=item * Southwark does not allow users to reopen reports.

=back

=cut

sub reopening_disallowed { 1 }

=head2 lookup_site_code

Reports sent to Confirm have a "site code" which is usually the USRN of the
street they're on. For reports made within estates Southwark don't want the
street USRN to be used, but rather the site code of the estate.

This code ensures the estate site code is used even if the report was made
on a street that happens to be within an estate.

=cut

sub lookup_site_code {
    my $self = shift;
    my $row = shift;
    my $field = shift;

    if (my $feature = $self->estate_feature_for_point($row->latitude, $row->longitude)) {
        return $feature->{properties}->{Site_code};
    }

    return $self->SUPER::lookup_site_code($row, $field);
}


=head2 lookup_site_code_config

When looking up the USRN of a street where a report was made, numbered roads within
Southwark must be ignored as Southwark's Confirm system is setup to reject
reports made on such streets. The majority of these street features actually
have an overlapping named road which will be found and used instead.

=cut

sub lookup_site_code_config {
    my $host = FixMyStreet->config('STAGING_SITE') ? "tilma.staging.mysociety.org" : "tilma.mysociety.org";
    return {
        buffer => 50, # metres
        url => "https://$host/mapserver/southwark",
        srsname => "urn:ogc:def:crs:EPSG::27700",
        typename => "LSG",
        property => "USRN",
        accept_feature => sub {
            # Roads that only have a number, not a name, mustn't be used for
            # site codes as they're not something Southwark can deal with.
            # For example "A201", "A3202", "B205", "C5840067" etc.
            my $feature = shift;
            my $name = $feature->{properties}->{Street_or_numbered_street} || "";
            return ( $name =~ /^[ABC][\d]+/ ) ? 0 : 1;
        }
    };
}

sub report_new_is_in_estate {
    my ( $self ) = @_;

    return $self->estate_feature_for_point(
        $self->{c}->stash->{latitude},
        $self->{c}->stash->{longitude}
    ) ? 1 : 0;
}


=head2 estate_feature_for_point

Takes a coordinate (as latitude & longitude) and queries the Southwark Estates
asset layer on our tilma WFS server to determine whether the coordinate lies
within an estate. If it does, the feature is returned.

=cut

sub estate_feature_for_point {
    my ( $self, $lat, $lon ) = @_;

    my ($x, $y) = Utils::convert_latlon_to_en($lat, $lon, 'G');

    my $host = FixMyStreet->config('STAGING_SITE') ? "tilma.staging.mysociety.org" : "tilma.mysociety.org";
    my $cfg = {
        url => "https://$host/mapserver/southwark",
        srsname => "urn:ogc:def:crs:EPSG::27700",
        typename => "Estates",
        filter => "<Filter><Contains><PropertyName>Geometry</PropertyName><gml:Point><gml:coordinates>$x,$y</gml:coordinates></gml:Point></Contains></Filter>",
    };

    my $features = $self->_fetch_features($cfg, $x, $y);
    return $features->[0];
}


=head2 category_groups_to_skip

Southwark do not want certain TfL categories to appear, dependent on
whether an 'estates' or 'street' area has been selected

=cut

sub category_groups_to_skip {
    return {
        estates => [
            'Bus Stations',
            'Bus Stops and Shelters',
            'River Piers',
            'Traffic Lights',
        ],
        street => [
            'River Piers',
        ],
    };
}


=head2 munge_categories

Southwark have two distinct sets of categories that are shown to the user
depending on whether the report they're making is inside or outside an estate.

Categories for estates have service codes that start with HOU_, and street
categories start with STCL_.

Some additional filtering is done on top of that to remove some TfL categories,
as determined by C<category_groups_to_skip>.

=cut

sub munge_categories {
    my ( $self, $contacts ) = @_;

    if ( $self->report_new_is_in_estate ) {
        @$contacts = grep {
            $_->email !~ /^STCL_/;
        } @$contacts;

        @$contacts = _filter_categories_by_group( $contacts, 'estates' );
    } else {
        @$contacts = grep {
            $_->email !~ /^HOU_/;
        } @$contacts;

        @$contacts = _filter_categories_by_group( $contacts, 'street' );
    }
}


=head2 _filter_categories_by_group

Returns an array of contacts that have some TfL categories removed, according
to the list specified in C<category_groups_to_skip>.

=cut

sub _filter_categories_by_group {
    # $area_type is either 'estates' or 'street'
    my ( $contacts, $area_type ) = @_;

    my %contacts_hash = map { $_->category => $_ } @$contacts;

    for my $contact ( values %contacts_hash ) {
        for my $group ( @{ $contact->groups } ) {
            if ( any { $_ eq $group }
                @{ category_groups_to_skip()->{$area_type} } )
            {
                delete $contacts_hash{ $contact->category };
                last;
            }
        }
    }

    return values %contacts_hash;
}

=head2 dashboard_export_problems_add_columns

Has user email added to their csv reports export.

=cut

sub dashboard_export_problems_add_columns {
    my ($self, $csv) = @_;

    $csv->add_csv_columns(
        user_email => 'User Email',
    );

    $csv->objects_attrs({
        '+columns' => ['user.email'],
        join => 'user',
    });

    return if $csv->dbi; # user_email already included.

    $csv->csv_extra_data(sub {
        my $report = shift;
        return {
            user_email => $report->user ? $report->user->email : '',
        };
    });
}


1;
