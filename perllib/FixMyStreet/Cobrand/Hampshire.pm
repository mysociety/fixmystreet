package FixMyStreet::Cobrand::Hampshire;
use parent 'FixMyStreet::Cobrand::Whitelabel';

use strict;
use warnings;

use Moo;
with 'FixMyStreet::Roles::ConfirmOpen311';
with 'FixMyStreet::Roles::ConfirmValidation';

sub council_area_id { return 2227; } # https://mapit.mysociety.org/area/2227.html
sub council_area { return 'Hampshire'; }
sub council_name { return 'Hampshire County Council'; }
sub council_url { return 'hampshire'; }
sub base_url { return FixMyStreet->config('BASE_URL'); }

# Created with bin/fixmystreet.com/generate_council_location
sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;
    return {
        %{ $self->SUPER::disambiguate_location() },
        centre => '51.064173482874,-1.28695905016577',
        span   => '0.677947505634364,1.22793350685304',
        bounds => [ 50.7059677704377, -1.95727712614646, 51.3839152760721, -0.729343619293414 ],
    };
}

sub lookup_site_code_config { {
    buffer => 200, # metres
    url => "https://tilma.mysociety.org/mapserver/hampshire",
    srsname => "urn:ogc:def:crs:EPSG::27700",
    typename => "Road_Sections",
    property => "SITE_CODE",
    accept_feature => sub { 1 }
} }

1;
