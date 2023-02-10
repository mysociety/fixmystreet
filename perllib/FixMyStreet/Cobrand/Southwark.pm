package FixMyStreet::Cobrand::Southwark;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

use List::Util qw(any);
use Moo;

with 'FixMyStreet::Roles::ConfirmOpen311';
with 'FixMyStreet::Roles::ConfirmValidation';

sub council_area_id { 2491 }
sub council_area { 'Southwark' }
sub council_name { 'Southwark Council' }
sub council_url { 'southwark' }

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

sub reopening_disallowed {
    my ($self, $problem) = @_;
    # allow admins to restrict staff from reopening categories using category control
    return 1 if $self->next::method($problem);
    # only Southwark staff may reopen reports
    my $user = $self->{c}->user_exists ? $self->{c}->user : undef;
    return 0 if ($user && $user->from_body && $user->from_body->cobrand_name eq $self->council_name);
    return 1;
}

sub lookup_site_code {
    my $self = shift;
    my $row = shift;
    my $field = shift;

    if (my $feature = $self->estate_feature_for_point($row->latitude, $row->longitude)) {
        return $feature->{properties}->{Site_code};
    }

    return $self->SUPER::lookup_site_code($row, $field);
}


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

# Southwark do not want certain TfL categories to appear, dependent on
# whether an 'estates' or 'street' area has been selected
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

sub allow_anonymous_reports { 'button' }

sub anonymous_account {
    my $self = shift;
    return {
        email => $self->feature('anonymous_account') . '@' . $self->admin_user_domain,
        name => 'Anonymous user',
    };
}

sub privacy_policy_url { 'https://www.southwark.gov.uk/council-and-democracy/freedom-of-information-and-data-protection/corporate-data-privacy-notice' }

sub contact_extra_fields { [ 'display_name' ] }

1;
