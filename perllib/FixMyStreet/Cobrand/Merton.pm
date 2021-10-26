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

sub enter_postcode_text { 'Enter a postcode, street name and area, or check an existing report number' }

sub admin_user_domain { 'merton.gov.uk' }

sub privacy_policy_url { "https://www.merton.gov.uk/legal/privacy-and-cookies" }

sub open311_config {
    my ($self, $row, $h, $params) = @_;

    $params->{multi_photos} = 1;
    $params->{upload_files} = 1;
}

sub reopening_disallowed {
    my ($self, $problem) = @_;
    # allow admins to restrict staff from reopening categories using category control
    return 1 if $self->next::method($problem);
    # only Merton staff may reopen reports
    my $c = $self->{c};
    my $user = $c->user;
    return 0 if ($c->user_exists && $user->from_body && $user->from_body->cobrand_name eq 'Merton Council');
    return 1;
}

sub open311_extra_data_include {
    my ($self, $row, $h) = @_;

    my $open311_only = [
        { name => 'service', value => $row->service },
    ];

    # Reports made via FMS.com or the app probably won't have a USRN
    # value because we don't access the USRN layer on those
    # frontends. Instead we'll look up the closest asset from the WFS
    # service at the point we're sending the report over Open311.
    if (!$row->get_extra_field_value('usrn')) {
        if (my $usrn = $self->lookup_site_code($row, 'usrn')) {
            $row->update_extra_field({ name => 'usrn', value => $usrn });
        }
    }

    return $open311_only;
}

sub lookup_site_code_config { {
    buffer => 50, # metres
    url => FixMyStreet->config('STAGING_SITE') ? "https://tilma.staging.mysociety.org/mapserver/openusrn" : "https://tilma.mysociety.org/mapserver/openusrn",
    srsname => "urn:ogc:def:crs:EPSG::27700",
    typename => 'usrn',
    property => "usrn",
    accept_feature => sub { 1 },
} }

sub cut_off_date { '2020-12-06' } # 1 yr prior to FMS Pro go-live

1;
