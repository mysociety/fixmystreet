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

1;

