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

sub lookup_site_code_config {
    my $host = FixMyStreet->config('STAGING_SITE') ? "tilma.staging.mysociety.org" : "tilma.mysociety.org";
    return {
        buffer => 50, # metres
        url => "https://$host/mapserver/southwark",
        srsname => "urn:ogc:def:crs:EPSG::27700",
        typename => "LSG",
        property => "USRN",
        accept_feature => sub { 1 }
    };
}

sub report_new_is_in_estate {
    my ( $self ) = @_;

    my ($x, $y) = Utils::convert_latlon_to_en(
        $self->{c}->stash->{latitude},
        $self->{c}->stash->{longitude},
        'G'
    );

    my $host = FixMyStreet->config('STAGING_SITE') ? "tilma.staging.mysociety.org" : "tilma.mysociety.org";
    my $cfg = {
        url => "https://$host/mapserver/southwark",
        srsname => "urn:ogc:def:crs:EPSG::27700",
        typename => "Estates",
        filter => "<Filter><Contains><PropertyName>Geometry</PropertyName><gml:Point><gml:coordinates>$x,$y</gml:coordinates></gml:Point></Contains></Filter>",
    };

    my $features = $self->_fetch_features($cfg, $x, $y);
    return scalar @$features ? 1 : 0;
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


1;
