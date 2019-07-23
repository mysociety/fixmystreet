package FixMyStreet::Cobrand::Westminster;
use base 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

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

sub enter_postcode_text {
    my ($self) = @_;
    return 'Enter a ' . $self->council_area . ' postcode, or street name';
}

sub send_questionnaires { 0 }

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

1;
