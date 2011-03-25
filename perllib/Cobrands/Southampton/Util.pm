#!/usr/bin/perl -w
#
# Util.pm:
# Southampton cobranding for FixMyStreet.
#
# Copyright (c) 2011 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org

package Cobrands::Southampton::Util;
use strict;
use Carp;
use URI::Escape;
use mySociety::VotingArea;

sub new {
    my $class = shift;
    return bless {}, $class;
}

=item site_restriction Q

Return a site restriction clause and a site key.

=cut
sub site_restriction {
    return ("and council='2567'", 'southampton');
}

=item

Return the base url for this cobranded site

=cut

sub base_url {
   my $base_url = mySociety::Config::get('BASE_URL');
   if ($base_url !~ /southampton/) {
       $base_url =~ s/http:\/\/(?!www\.)/http:\/\/southampton\./g;
       $base_url =~ s/http:\/\/www\./http:\/\/southampton\./g;
   }
   return $base_url;
}

=item site_title

Return the title to be used in page heads

=cut 

sub site_title { 
    my ($self) = @_;
    return 'Southampton City Council FixMyStreet';
}

sub enter_postcode_text {
    my ($self,$q) = @_;
    return 'Enter a Southampton postcode, or street name and area';
}

=item council_check COUNCILS QUERY CONTEXT

Return a boolean indicating whether COUNCILS are okay for the location
in the QUERY, and an error message appropriate to the CONTEXT.

=cut

sub council_check {
    my ($self, $params, $q, $context) = @_;
    my $councils;
    if ($params->{all_councils}) {
        $councils = $params->{all_councils};
    } elsif (defined $params->{lat}) {
        my $parent_types = $mySociety::VotingArea::council_parent_types;
        $councils = mySociety::MaPit::call('point', "4326/$params->{lon},$params->{lat}", type => $parent_types);
    }
    my $council_match = defined $councils->{2567};
    if ($council_match) {
        return 1;
    }
    my $url = 'http://www.fixmystreet.com/';
    $url .= 'alert' if $context eq 'alert';
    $url .= '?pc=' . URI::Escape::uri_escape_utf8($q->param('pc')) if $q->param('pc');
    my $error_msg = "That location is not covered by Southampton.
Please visit <a href=\"$url\">the main FixMyStreet site</a>.";
    return (0, $error_msg);
}

# All reports page only has the one council.
sub all_councils_report {
    return 0;
}

=item disambiguate_location S Q

Given a string representing a location (street and area expected),
bias the viewport to around Southampton.

=cut
 
sub disambiguate_location {
    my ($self, $s, $q) = @_;
    $s = "ll=50.913822,-1.400493&spn=0.084628,0.15701&$s";
    return $s;
} 

sub recent_photos {
    my ($self, $num, $lat, $lon, $dist) = @_;
    $num = 2 if $num == 3;
    return Problems::recent_photos($num, $lat, $lon, $dist);
}

1;

