#!/usr/bin/perl -w
#
# Util.pm:
# Fiksgatami cobranding for FixMyStreet.
#
# Copyright (c) 2011 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org

package Cobrands::Fiksgatami::Util;
use strict;
use Carp;

sub new {
    my $class = shift;
    return bless {}, $class;
}

sub set_lang_and_domain {
    my ($self, $lang, $unicode) = @_;
    mySociety::Locale::negotiate_language('en-gb,English,en_GB|nb,Norwegian,nb_NO', 'nb');
    mySociety::Locale::gettext_domain('FixMyStreet', $unicode);
    mySociety::Locale::change(); 
}

# If lat/lon are present in the URL, OpenLayers will use that to centre the map.
# Need to specify a zoom to stop it defaulting to null/0.
sub url {
    my ($self, $url) = @_;
    if ($url =~ /lat=/ && $url !~ /zoom=/) {
        $url .= ';zoom=2';
    }
    return $url;
}

sub enter_postcode_text {
    my ($self, $q) = @_;
    return _('Enter a nearby postcode, or street name and area');
}

# Is also adding language parameter
sub disambiguate_location {
    my ($self, $s, $q) = @_;
    $s = "hl=no&gl=no&$s";
    return $s;
}

sub geocoded_string_check {
    my ($self, $s) = @_;
    return 1 if $s =~ /, Norge/;
    return 0;
}

sub area_types {
    return ( 'NKO', 'NFY' );
}

sub area_min_generation {
    return '';
}

sub admin_base_url {
    return 'http://www.fiksgatami.no/admin/';
}

sub writetothem_url {
    return 'http://www.norge.no/styresmakter/';
}

sub find_closest {
    my ($self, $latitude, $longitude) = @_;
    my $str = '';
    $str .= FixMyStreet::Geocode::OSM::closest_road_text($latitude,
                                                         $longitude);
    return $str;
}


1;

