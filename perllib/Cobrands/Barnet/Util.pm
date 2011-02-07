#!/usr/bin/perl -w
#
# Util.pm:
# Barnet cobranding for FixMyStreet.
#
# Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org

package Cobrands::Barnet::Util;
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
sub site_restriction{
    return ("and council='2489'", 'barnet');
}

=item

Return the base url for this cobranded site

=cut

sub base_url {
   my $base_url = mySociety::Config::get('BASE_URL');
   if ($base_url !~ /barnet/) {
       $base_url =~ s/http:\/\/(?!www\.)/http:\/\/barnet\./g;
       $base_url =~ s/http:\/\/www\./http:\/\/barnet\./g;
   }
   return $base_url;
}

=item site_title

Return the title to be used in page heads

=cut 

sub site_title { 
    my ($self) = @_;
    return 'Barnet Council FixMyStreet';
}

sub enter_postcode_text {
    my ($self,$q) = @_;
    return 'Enter a Barnet postcode, or street name and area:';
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
    } elsif ($params->{e}) {
        my $parent_types = $mySociety::VotingArea::council_parent_types;
        $councils = mySociety::MaPit::call('point', "27700/$params->{e},$params->{n}", type => $parent_types);
    }
    my $council_match = defined $councils->{2489};
    if ($council_match) {
        return 1;
    }
    my $url = 'http://www.fixmystreet.com/';
    $url .= 'alert' if $context eq 'alert';
    $url .= '?pc=' . URI::Escape::uri_escape_utf8($q->param('pc')) if $q->param('pc');
    my $error_msg = "That location is not covered by Barnet.
Please visit <a href=\"$url\">the main FixMyStreet site</a>.";
    return (0, $error_msg);
}

# All reports page only has the one council.
sub all_councils_report {
    return 0;
}

=item disambiguate_location S Q

Given a string representing a location (street and area expected),
bias the viewport to around Barnet.

=cut
 
sub disambiguate_location {
    my ($self, $s, $q) = @_;
    $s = "ll=51.612832,-0.218169&spn=0.0563,0.09&$s";
    return $s;
} 

sub recent_photos {
    my ($self, $num, $lat, $lon, $dist) = @_;
    $num = 2 if $num == 3;
    return Problems::recent_photos($num, $lat, $lon, $dist);
}

1;

