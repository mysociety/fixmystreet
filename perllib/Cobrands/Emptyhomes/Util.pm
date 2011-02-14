#!/usr/bin/perl -w
#
# Util.pm:
# Emptyhomes Cobranding for FixMyStreet.
#
# Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: louise@mysociety.org. WWW: http://www.mysociety.org

package Cobrands::Emptyhomes::Util;
use strict;
use Carp;

sub new {
    my $class = shift;
    return bless {}, $class;
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

sub admin_base_url {
    return 'https://secure.mysociety.org/admin/emptyhomes/';
}

sub area_types {
    return [qw(DIS LBO MTD UTA LGD COI)]; # No CTY
}

=item set_lang_and_domain LANG UNICODE

Set the language and text domain for the site based on the query and host. 

=cut

sub set_lang_and_domain {
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

=item feed_xsl

Return the XSL file path to be used for feeds'

=cut
sub feed_xsl {
    my ($self) = @_;
    return '/xsl.eha.xsl';
}

1;

