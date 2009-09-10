#!/usr/bin/perl -w
#
# Cobrand.pm:
# Cobranding for FixMyStreet.
#
# 
# Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: louise@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: Cobrand.pm,v 1.12 2009-09-10 08:54:34 louise Exp $

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

=item base_url COBRAND

Return the base url for the cobranded version of the site

=cut
sub base_url{
    my $cobrand = shift;
    return mySociety::Config::get('BASE_URL') unless $cobrand;
    my $handle = cobrand_handle($cobrand);
    return mySociety::Config::get('BASE_URL') unless $handle;
    return $handle->base_url();
}

=item contact_email COBRAND

Return the contact email for the cobranded version of the site

=cut
sub contact_email{
    my $cobrand = shift;
    $cobrand = uc($cobrand);
    my $sender;
    if ($cobrand){
        $sender = mySociety::Config::get("CONTACT_EMAIL_" . $cobrand, undef);
    }
    if (!$sender){  
        $sender = mySociety::Config::get('CONTACT_EMAIL');
    }
    return $sender;
}

=item set_lang_and_domain COBRAND LANG

Set the language and domain of the site based on the cobrand and host

=cut
sub set_lang_and_domain($$;$) {
  my ($cobrand, $lang, $unicode) = @_;
  if ($cobrand){
      my $handle = cobrand_handle($cobrand);
      if ($handle){
            $handle->set_lang_and_domain($lang);
      }
  }else{
        mySociety::Locale::negotiate_language('en-gb,English,en_GB|nb,Norwegian,nb_NO'); # XXX Testing
        mySociety::Locale::gettext_domain('FixMyStreet', $unicode);
        mySociety::Locale::change(); 
  }
}

1;

