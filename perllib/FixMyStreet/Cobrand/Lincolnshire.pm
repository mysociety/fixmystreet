package FixMyStreet::Cobrand::Lincolnshire;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

use LWP::Simple;
use URI;
use Try::Tiny;
use JSON::MaybeXS;

use Moo;
with 'FixMyStreet::Roles::ConfirmOpen311';
with 'FixMyStreet::Roles::ConfirmValidation';

sub council_area_id { return 2232; }
sub council_area { return 'Lincolnshire'; }
sub council_name { return 'Lincolnshire County Council'; }
sub council_url { return 'lincolnshire'; }
sub is_two_tier { 1 }

sub send_questionnaires { 0 }
sub report_sent_confirmation_email { 'external_id' }

sub admin_user_domain { 'lincolnshire.gov.uk' }

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
        'body.name' => [ "Lincolnshire County Council", 'Highways England' ],

        # District categories:
        'me.category' => { -in => [
            'Street nameplates',
            'Bench/cycle rack/litter bin/planter',
        ] },
    ] } );
}

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    my $ext_status = $p->get_extra_metadata('external_status_code');
    return 'yellow' if $p->state eq 'confirmed' && $ext_status && $ext_status eq '0135';
    return 'red' if $p->state eq 'confirmed';
    return 'green' if $p->is_fixed || $p->is_closed;
    return 'grey' if $p->state eq 'not responsible' || !$self->owns_problem( $p );
    return 'yellow';
}

1;
