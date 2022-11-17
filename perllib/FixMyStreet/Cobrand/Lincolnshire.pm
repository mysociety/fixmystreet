package FixMyStreet::Cobrand::Lincolnshire;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

use LWP::Simple;
use URI;
use Try::Tiny;
use JSON::MaybeXS;
use FixMyStreet::DB;

use Moo;
with 'FixMyStreet::Roles::ConfirmOpen311';
with 'FixMyStreet::Roles::ConfirmValidation';

sub council_area_id { return 2232; }
sub council_area { return 'Lincolnshire'; }
sub council_name { return 'Lincolnshire County Council'; }
sub council_url { return 'lincolnshire'; }
sub is_two_tier { 1 }

sub on_map_default_status { 'open' }

sub send_questionnaires { 0 }
sub report_sent_confirmation_email { 'external_id' }

sub admin_user_domain { 'lincolnshire.gov.uk' }

sub default_map_zoom { 5 }

sub enter_postcode_text {
    my ($self) = @_;
    return 'Enter a Lincolnshire postcode, street name and area, or check an existing report number';
}

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;
    return {
        %{ $self->SUPER::disambiguate_location() },
        town   => 'Lincolnshire',
        centre => '53.1128371079972,-0.237920757894981',
        span   => '0.976148231905086,1.17860658530345',
        bounds => [ 52.6402179235688, -0.820651304784901, 53.6163661554738, 0.357955280518546 ],
    };
}


sub lookup_site_code_config { {
    buffer => 200, # metres
    url => "https://tilma.mysociety.org/mapserver/lincs",
    srsname => "urn:ogc:def:crs:EPSG::27700",
    typename => "NSG",
    property => "Site_Code",
    accept_feature => sub { 1 }
} }


sub categories_restriction {
    my ($self, $rs) = @_;
    # Lincolnshire is a two-tier council, but don't want to display
    # all district-level categories on their cobrand - just a couple.
    return $rs->search( { -or => [
        'body.name' => [ "Lincolnshire County Council", 'National Highways' ],

        # District categories:
        'me.category' => { -in => [
            'Litter',
            'Street nameplates',
            'Bench', 'Cycle rack', 'Litter bin', 'Planter',
        ] },
    ] } );
}

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    my $ext_status = $p->get_extra_metadata('external_status_code');

    return 'grey'
        if $p->state eq 'not responsible' || !$self->owns_problem($p);
    return 'orange'
        if $p->state eq 'investigating' || $p->state eq 'for triage';
    return 'yellow'
        if $p->state eq 'action scheduled' || $p->state eq 'in progress';
    return 'green' if $p->is_fixed;
    return 'blue' if $p->is_closed;
    return 'red';
}

around 'open311_config' => sub {
    my ($orig, $self, $row, $h, $params) = @_;

    $params->{upload_files} = 1;
    $self->$orig($row, $h, $params);
};

# Find or create a user to associate with externally created Open311 reports.
sub open311_get_user {
    my ($self, $request) = @_;

    return unless $request->{contact_name} && $request->{contact_email};

    if (FixMyStreet->config("STAGING_SITE")) { {
        # In staging we don't want to store private contact information
        # so only return a user if the email address is @lincolnshire.gov.uk
        # or a superuser with the email address already exists.
        my $domain = $self->admin_user_domain;
        last if $request->{contact_email} =~ /[@]$domain$/;
        last if FixMyStreet::DB->resultset('User')->find({
            email => $request->{contact_email},
            email_verified => 1,
            is_superuser => 1,
        });
        return;
    } }

    return FixMyStreet::DB->resultset('User')->find_or_create(
        {
            name => $request->{contact_name},
            email => $request->{contact_email},
            email_verified => 1,
        },
        { key => 'users_email_verified_key' },
    );
}

1;
