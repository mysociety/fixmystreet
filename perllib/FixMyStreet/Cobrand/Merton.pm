package FixMyStreet::Cobrand::Merton;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

sub council_area_id { 2500 }
sub council_area { 'Merton' }
sub council_name { 'Merton Council' }
sub council_url { 'merton' }
sub send_questionnaires { 0 }

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    my $town = "Merton";

    return {
        %{ $self->SUPER::disambiguate_location() },
        town => $town,
        centre => '51.4099496632915,-0.197255310605401',
        span   => '0.0612811278185319,0.130096741684365',
        bounds => [ 51.3801834993027, -0.254262247988426, 51.4414646271213, -0.124165506304061 ],
    };
}

sub report_validation {
    my ($self, $report, $errors) = @_;

    my @extra_fields = @{ $report->get_extra_fields() };

    my %max = (
        vehicle_registration_number => 15,
        vehicle_make_model => 50,
        vehicle_colour => 50,
    );

    foreach my $extra ( @extra_fields ) {
        my $max = $max{$extra->{name}} || 100;
        if ( length($extra->{value}) > $max ) {
            $errors->{'x' . $extra->{name}} = qq+Your answer to the question: "$extra->{description}" is too long. Please use a maximum of $max characters.+;
        }
    }

    return $errors;
}

sub enter_postcode_text { 'Enter a postcode, street name and area, or check an existing report number' }

sub get_geocoder { 'OSM' }

sub admin_user_domain { 'merton.gov.uk' }

sub allow_anonymous_reports { 'button' }

sub anonymous_account {
    my $self = shift;
    return {
        # Merton requested something other than @merton.gov.uk due to their CRM misattributing reports to staff.
        email => $self->feature('anonymous_account') . '@anonymous-fms.merton.gov.uk',
        name => 'Anonymous user',
    };
}

sub open311_config {
    my ($self, $row, $h, $params) = @_;

    $params->{multi_photos} = 1;
    $params->{upload_files} = 1;
}

sub open311_extra_data_include {
    my ($self, $row, $h) = @_;

    # Reports made via FMS.com or the app probably won't have a USRN
    # value because we don't access the USRN layer on those
    # frontends. Instead we'll look up the closest asset from the WFS
    # service at the point we're sending the report over Open311.
    if (!$row->get_extra_field_value('usrn')) {
        if (my $usrn = $self->lookup_site_code($row, 'usrn')) {
            $row->update_extra_field({ name => 'usrn', value => $usrn });
        }
    }

    return [];
}

sub report_new_munge_before_insert {
    my ($self, $report) = @_;

    return unless $report->to_body_named('Merton');

    # Workaround for anonymous reports not having a service associated with them.
    if (!$report->service) {
        $report->service('unknown');
    }

    # Save the service attribute into extra data as well as in the
    # problem to avoid having the field appear as blank and required
    # in the inspector toolbar for users with 'inspect' permissions.
    if (!$report->get_extra_field_value('service')) {
        $report->update_extra_field({ name => 'service', value => $report->service });
    }
}

sub lookup_site_code {
    my $self = shift;
    my $row = shift;
    my $field = shift;

    my ($x, $y) = $row->local_coords;
    my $buffer = 50;
    my ($w, $s, $e, $n) = ($x-$buffer, $y-$buffer, $x+$buffer, $y+$buffer);

    my $filter = "
    <ogc:Filter xmlns:ogc=\"http://www.opengis.net/ogc\">
        <ogc:And>
            <ogc:PropertyIsNotEqualTo>
                <ogc:PropertyName>street_type</ogc:PropertyName>
                <ogc:Literal>Numbered Street</ogc:Literal>
            </ogc:PropertyIsNotEqualTo>
            <ogc:BBOX>
                <ogc:PropertyName>geometry</ogc:PropertyName>
                <gml:Envelope xmlns:gml='http://www.opengis.net/gml' srsName='EPSG:27700'>
                    <gml:lowerCorner>$w $s</gml:lowerCorner>
                    <gml:upperCorner>$e $n</gml:upperCorner>
                </gml:Envelope>
                <Distance units='m'>50</Distance>
            </ogc:BBOX>
        </ogc:And>
    </ogc:Filter>";
    $filter =~ s/\n\s+//g;

    my $cfg = {
        url => FixMyStreet->config('STAGING_SITE') ? "https://tilma.staging.mysociety.org/mapserver/openusrn" : "https://tilma.mysociety.org/mapserver/openusrn",
        srsname => "urn:ogc:def:crs:EPSG::27700",
        typename => 'usrn',
        property => "usrn",
        filter => $filter,
        accept_feature => sub { 1 },
    };

    my $features = $self->_fetch_features($cfg, $x, $y);
    return $self->_nearest_feature($cfg, $x, $y, $features);
}

sub cut_off_date { '2021-12-13' } # Merton cobrand go-live

sub report_age { '3 months' }

sub abuse_reports_only { 1 }

1;
