#!/usr/bin/perl -w
#
# Util.pm:
# Barnet cobranding for FixMyStreet.
#
#
# Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: Util.pm,v 1.3 2009-12-22 11:02:47 matthew Exp $

package Cobrands::Barnet::Util;
use Standard;
use strict;
use Carp;
use mySociety::Web qw(ent);

sub new {
    my $class = shift;
    return bless {}, $class;
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

Return a boolean indicating whether the councils for the location passed any
extra checks defined by the cobrand ousing data in the query

=cut

sub council_check {
    my ($self, $councils, $q, $context) = @_;
    my $council_match = defined $councils->{2489};
    if ($council_match) {
        return 1;
    }
    my $error_msg = "That location is not covered by Barnet.
Please visit <a href='http://www.fixmystreet.com/'>the main FixMyStreet site</a>.";
    #if ($context eq 'submit_problem' or $context eq 'display_location') {
    #     $error_msg .= "You can report a problem at this location at $main_app_link.";
    #} else {
    #     $error_msg .= "You can subscribe to alerts for this area at $main_app_link.";
    #}
    return (0, $error_msg);
}

# All reports page only has the one council.
sub all_councils_report {
    return 0;
}

1;

