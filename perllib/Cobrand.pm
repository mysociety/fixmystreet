#!/usr/bin/perl -w
#
# Cobrand.pm:
# Cobranding for FixMyStreet.
#
# 
# Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: louise@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: Cobrand.pm,v 1.9 2009-09-02 11:35:18 matthew Exp $

package Cobrand;
use strict;
use Carp;

=item get_allowed_cobrands

Return an array reference of allowed cobrand subdomains

=cut
sub get_allowed_cobrands{
    my $allowed_cobrand_string = mySociety::Config::get('ALLOWED_COBRANDS');
    my @allowed_cobrands = split(/\|/, $allowed_cobrand_string);
    return \@allowed_cobrands;
}

=item cobrand_handle Q

Given a query that has the name of a site set, return a handle to the Util module for that
site, if one exists, or zero if not.

=cut
sub cobrand_handle {
    my $cobrand = shift;

    our %handles;

    # Once we have a handle defined, return it.
    return $handles{$cobrand} if defined $handles{$cobrand};

    my $cobrand_class = ucfirst($cobrand);
    my $class = "Cobrands::" . $cobrand_class . "::Util";
    eval "use $class";

    eval{ $handles{$cobrand} = $class->new };
    $handles{$cobrand} = 0 if $@;
    return $handles{$cobrand};
}


=item cobrand_page QUERY

Return a string containing the HTML to be rendered for a custom Cobranded page

=cut
sub cobrand_page{
    my $q = shift;
    my $cobrand = $q->{site};
    my $handle = cobrand_handle($cobrand);
    return 0 unless $handle;
    return $handle->page($q);	
}

=item set_site_restriction Q

Return a site restriction clause and a site key if the cobrand uses a subset of the FixMyStreet 
data. Q is the query object. Returns an empty string and site key 0 if the cobrand uses all the 
data.

=cut
sub set_site_restriction{
    my $q = shift;
    my $site_restriction = '';
    my $site_id = 0;
    my $cobrand = $q->{site};
    my $handle = cobrand_handle($cobrand);
    return ($site_restriction, $site_id) unless $handle;
    return $handle->site_restriction($q);
}


=item set_lang_and_domain COBRAND LANG

Set the language and domain of the site based on the cobrand and host
=cut
sub set_lang_and_domain{
  my ($cobrand, $lang) = @_;
  my $handle = cobrand_handle($cobrand);
  if ($handle){
       $handle->set_lang_and_domain($lang);
  }
}

1;

