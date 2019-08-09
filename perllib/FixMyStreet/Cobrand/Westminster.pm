package FixMyStreet::Cobrand::Westminster;
use base 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

use URI;

sub council_area_id { return 2504; }
sub council_area { return 'Westminster'; }
sub council_name { return 'Westminster City Council'; }
sub council_url { return 'Westminster'; }

sub disambiguate_location {
    my $self = shift;
    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => 'Westminster',
        centre => '51.513444,-0.160467',
        bounds => [ 51.483816, -0.216088, 51.539793, -0.111101 ],
    };
}

sub get_geocoder {
    return 'OSM'; # default of Bing gives poor results, let's try overriding.
}

sub enter_postcode_text {
    my ($self) = @_;
    return 'Enter a ' . $self->council_area . ' postcode, or street name';
}

sub send_questionnaires { 0 }

sub updates_disallowed {
    my $self = shift;
    my $c = $self->{c};

    # Only WCC staff and superusers can leave updates
    my $staff = $c->user_exists && $c->user->from_body && $c->user->from_body->name eq $self->council_name;
    my $superuser = $c->user_exists && $c->user->is_superuser;

    return ( $staff || $superuser ) ? 0 : 1;
 }

sub suppress_reporter_alerts { 1 }

sub social_auth_enabled {
    my $self = shift;

    return $self->feature('oidc_login') ? 1 : 0;
}

sub allow_anonymous_reports { 'button' }

sub admin_user_domain { 'westminster.gov.uk' }

sub anonymous_account {
    my $self = shift;
    return {
        email => $self->feature('anonymous_account') . '@' . $self->admin_user_domain,
        name => 'Anonymous user',
    };
}

sub oidc_user_extra {
    my ($self, $id_token) = @_;

    # Westminster want the CRM ID of the user to be passed in the
    # account_id field of Open311 POST Service Requests, so
    # extract it from the id token and store in user extra
    # if it's available.
    my $crm_id = $id_token->payload->{extension_CrmContactId};

    return {
        $crm_id ? (westminster_account_id => $crm_id) : (),
    };
}

sub open311_config {
    my ($self, $row, $h, $params) = @_;

    my $id = $row->user->get_extra_metadata('westminster_account_id');
    # Westminster require 0 as the account ID if there's no MyWestminster ID.
    $h->{account_id} = $id || '0';

    my $extra = $row->get_extra_fields;

    # Reports made via the app probably won't have a USRN because we don't
    # display the road layer. Instead we'll look up the closest asset from the
    # asset service at the point we're sending the report over Open311.
    if (!$row->get_extra_field_value('USRN')) {
        if (my $ref = $self->lookup_site_code($row)) {
            push @$extra, { name => 'USRN', value => $ref };
        }
    }

    $row->set_extra_fields(@$extra);
}

sub lookup_site_code_config {
    # uncoverable subroutine
    # uncoverable statement
    {
        buffer => 1000, # metres
        proxy_url => "https://tilma.staging.mysociety.org/resource-proxy/proxy.php",
        url => "https://westminster.assets/40/query",
        property => "USRN",
        accept_feature => sub { 1 }
    }
}

sub _fetch_features_url {
    my ($self, $cfg, $w, $s, $e, $n) = @_;

    # Westminster's asset proxy has a slightly different calling style to
    # a standard WFS server.
    my $uri = URI->new($cfg->{url});
    $uri->query_form(
        inSR => "27700",
        outSR => "27700",
        f => "geojson",
        outFields => $cfg->{property},
        geometry => "$w,$s,$e,$n",
    );

    return $cfg->{proxy_url} . "?" . $uri->as_string;
}

1;
