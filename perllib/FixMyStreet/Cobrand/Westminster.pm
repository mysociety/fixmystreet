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

sub suppress_reporter_alerts { 1 }

sub report_age { '3 months' }

sub on_map_default_status { 'open' }

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
}

sub open311_extra_data {
    my ($self, $row, $h, $extra) = @_;

    # Reports made via the app probably won't have a USRN because we don't
    # display the road layer. Instead we'll look up the closest asset from the
    # asset service at the point we're sending the report over Open311.
    if (!$row->get_extra_field_value('USRN')) {
        if (my $ref = $self->lookup_site_code($row, 'USRN')) {
            push @$extra, { name => 'USRN', value => $ref };
        }
    }

    # Some categories require a UPRN to be set, so if the field is present
    # but empty then look it up.
    my $fields = $row->get_extra_fields;
    my ($uprn_field) = grep { $_->{name} eq 'UPRN' } @$fields;
    if ( $uprn_field && !$uprn_field->{value} ) {
        if (my $ref = $self->lookup_site_code($row, 'UPRN')) {
            push @$extra, { name => 'UPRN', value => $ref };
        }
    }

    return undef;
}

sub lookup_site_code_config {
    my ( $self, $field ) = @_;
    # uncoverable subroutine
    # uncoverable statement
    my $layer = $field eq 'USRN' ? '40' : '25'; # 25 is UPRN

    my %cfg = (
        buffer => 1000, # metres
        proxy_url => "https://tilma.mysociety.org/resource-proxy/proxy.php",
        url => "https://westminster.assets/$layer/query",
        property => $field,
        accept_feature => sub { 1 },

        # UPRNs are Point geometries, so make sure they're allowed by
        # _nearest_feature.
        ( $field eq 'UPRN' ) ? (accept_types => { Point => 1 }) : (),
    );
    return \%cfg;
}

sub _fetch_features_url {
    my ($self, $cfg) = @_;

    # Westminster's asset proxy has a slightly different calling style to
    # a standard WFS server.
    my $uri = URI->new($cfg->{url});
    $uri->query_form(
        inSR => "27700",
        outSR => "27700",
        f => "geojson",
        outFields => $cfg->{property},
        geometry => $cfg->{bbox},
    );

    return $cfg->{proxy_url} . "?" . $uri->as_string;
}

sub categories_restriction {
    my ($self, $rs) = @_;
    # Westminster don't want TfL or email categories on their cobrand.
    # Categories covering the council area have a mixture of Open311 and Email
    # send methods. We've set up the Email categories with a devolved
    # send_method, so can identify Open311 categories as those which have a
    # blank send_method.
    # XXX This still shows "These will be sent to TfL or Westminster City Council"
    # on /report/new before a category is selected...
    return $rs->search( {
            'body.name' => 'Westminster City Council',
            'me.send_method' => undef,
        }, { join => 'body' });
}

sub updates_restriction {
    my $self = shift;

    # Westminster don't want any fms.com updates shown on their cobrand.
    return $self->next::method(@_)->search({
        "me.cobrand" => { '!=', 'fixmystreet' }
    });
}

1;
