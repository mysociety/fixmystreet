#!/usr/bin/perl -w
#
# Util.pm:
# Emptyhomes Cobranding for FixMyStreet.
#
#
# Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: louise@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: Util.pm,v 1.5 2009-09-23 17:01:00 louise Exp $

package Cobrands::Emptyhomes::Util;
use Standard;
use strict;
use Carp;
use mySociety::Web qw(ent);

sub new{
    my $class = shift;
    return bless {}, $class;
}

=item site_restriction Q

Return a site restriction clause and a site key.

=cut
sub site_restriction{
    return ('', 0);
}

=item

Return the base url for this cobranded site

=cut

sub base_url {
   my $base_url = mySociety::Config::get('BASE_URL');
   if ($base_url !~ /emptyhomes/) {
       $base_url =~ s/http:\/\//http:\/\/emptyhomes\./g;
   }
   return $base_url;
}

=item

Return the list of custom pages that can be produced by this module

=cut

sub pages{
  return qw();
}

=item page Q

Return HTML for the page specified by the cobrand_page parameter in 
the query.

=cut

sub page{
   my $self = shift;
   my $q = shift;
   my $page_requested = $q->param('cobrand_page');
   if (grep ($_ eq $page_requested, $self->pages())){
      return $self->$page_requested($q);
   }else{      
    throw Error::Simple("Unknown page");
   }
}

=item set_lang_and_domain LANG UNICODE

Set the language and text domain for the site based on the query and host. 

=cut

sub set_lang_and_domain{
    my ($self, $lang, $unicode) = @_;
    mySociety::Locale::negotiate_language('en-gb,English,en_GB|cy,Cymraeg,cy_GB', $lang);
    mySociety::Locale::gettext_domain('FixMyStreet-EmptyHomes', $unicode);
    mySociety::Locale::change();
}

=item site_title

Return the title to be used in page heads

=cut 

sub site_title { 
    my ($self) = @_;
    return _('Report Empty Homes');
}

1;

