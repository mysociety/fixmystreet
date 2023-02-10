package FixMyStreet::Cobrand::Southwark;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

use Moo;
with 'FixMyStreet::Roles::ConfirmOpen311';
with 'FixMyStreet::Roles::ConfirmValidation';

sub council_area_id { 2491 }
sub council_area { 'Southwark' }
sub council_name { 'Southwark Council' }
sub council_url { 'southwark' }

sub cut_off_date { '2023-03-22' }

sub admin_user_domain { 'southwark.gov.uk' }

sub send_questionnaires { 0 }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    return {
        %{ $self->SUPER::disambiguate_location() },
        town => "Southwark",
        centre => '51.4742389056488,-0.0740567820867757',
        span   => '0.0893021072823146,0.0821035484648614',
        bounds => [ 51.4206051986445, -0.111491915302168, 51.5099073059268, -0.029388366837307 ],
    };
}


=item reopening_disallowed

Southwark only allow staff to reopen reports.

=cut

sub reopening_disallowed {
    my ($self, $problem) = @_;
    # allow admins to restrict staff from reopening categories using category control
    return 1 if $self->next::method($problem);
    # only Southwark staff may reopen reports
    my $user = $self->{c}->user_exists ? $self->{c}->user : undef;
    return 0 if ($user && $user->from_body && $user->from_body->cobrand_name eq $self->council_name);
    return 1;
}


=item lookup_site_code

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


=item lookup_site_code_config

When looking up the USRN of a street where a report was made, A-roads within
Southwark must be ignored as Southwark's Confirm system is setup to reject
reports made on such streets. The majority of these street features actually
have an overlapping non-A-road which will be found and used instead.

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
            # For example "A201", "A3202".
            my $feature = shift;
            my $name = $feature->{properties}->{Street_or_numbered_street} || "";
            return ( $name =~ /^A[\d]+/ ) ? 0 : 1;
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


=item estate_feature_for_point

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

sub munge_categories {
    my ($self, $contacts) = @_;
    if ( $self->report_new_is_in_estate ) {
        @$contacts = grep {
            $_->email !~ /^STCL_/;
        } @$contacts;
    } else {
        @$contacts = grep {
            $_->email !~ /^HOU_/;
        } @$contacts;
    }
}

sub allow_anonymous_reports { 'button' }

sub privacy_policy_url { 'https://www.southwark.gov.uk/council-and-democracy/freedom-of-information-and-data-protection/corporate-data-privacy-notice' }

sub contact_extra_fields { [ 'display_name' ] }

1;
