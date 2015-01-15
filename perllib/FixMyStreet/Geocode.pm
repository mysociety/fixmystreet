# FixMyStreet::Geocode
# The geocoding functions for FixMyStreet.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

package FixMyStreet::Geocode;

use strict;
use URI::Escape;
use FixMyStreet::Geocode::Bing;
use FixMyStreet::Geocode::Google;
use FixMyStreet::Geocode::OSM;
use FixMyStreet::Geocode::Zurich;

# lookup STRING CONTEXT
# Given a user-inputted string, try and convert it into co-ordinates using either
# MaPit if it's a postcode, or some web API otherwise. Returns an array of
# data, including an error if there is one. The information in the query may be
# used by cobranded versions of the site to diambiguate locations.
sub lookup {
    my ($s, $c) = @_;
    my $data = $c->cobrand->geocode_postcode($s);
    $data = string($s, $c)
        unless $data->{error} || defined $data->{latitude};
    $data->{error} = _('Sorry, we could not find that location.')
        unless $data->{error} || defined $data->{latitude};
    return ( $data->{latitude}, $data->{longitude}, $data->{error} );
}

# string STRING CONTEXT
# Passes the string to some external API to look stuff up.
sub string {
    my ($s, $c) = @_;

    my $service = $c->cobrand->get_geocoder($c);
    $service = $service->{type} if ref $service;
    $service = 'OSM' unless $service =~ /^(Bing|Google|OSM|Zurich)$/;
    $service = 'OSM' if $service eq 'Bing' && !FixMyStreet->config('BING_MAPS_API_KEY');
    $service = "FixMyStreet::Geocode::${service}::string";

    no strict 'refs';
    return &$service($s, $c);
}

# escape STRING CONTEXT
# Escapes string for putting in URL geocoding call
sub escape {
    my ($s, $c) = @_;
    $s = lc($s);
    $s =~ s/[^-&\w ']/ /g;
    $s =~ s/\s+/ /g;
    $s = URI::Escape::uri_escape_utf8($s);
    $s =~ s/%20/+/g;
    return $s;
}

1;
