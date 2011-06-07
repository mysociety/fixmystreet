#!/usr/bin/perl -w
#
# Page.t:
# Tests for the Page functions
#
#  Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: louise@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Page.t,v 1.12 2009-12-09 13:34:36 louise Exp $
#

use strict;
use warnings; 
use Test::More tests => 4;
use Test::Exception; 

use FindBin;
use lib "$FindBin::Bin";
use lib "$FindBin::Bin/../perllib";
use lib "$FindBin::Bin/../commonlib/perllib";

use Page;
use FixMyStreet::Geocode;
use mySociety::MockQuery;
use mySociety::Locale;

sub mock_query(){
    my $q  = new MockQuery('mysite');
    return $q;
}

sub set_lang($) {
    my $lang = shift;
    mySociety::Locale::negotiate_language($lang);
    mySociety::Locale::gettext_domain('FixMyStreet');
    mySociety::Locale::change();
}

sub test_base_url_with_lang {
    set_lang('en-gb,English,en_GB');
    my $q = mock_query();
    my $url = Page::base_url_with_lang($q);
    ok($url eq 'http://mysite.example.com', 'Basic url rendered ok');

    $q = new MockQuery('emptyhomes'); 
    $url = Page::base_url_with_lang($q);
    like($url, qr/http:\/\/en\.emptyhomes\./, 'Empty homes url with lang returned ok');	

    $url = Page::base_url_with_lang($q, 1);
    like($url, qr/http:\/\/cy\.emptyhomes\./, 'Empty homes url with lang reversed returned ok');	
 
}


ok(test_base_url_with_lang() == 1, 'Ran all tests for base_url_with_lang');
