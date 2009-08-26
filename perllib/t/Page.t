#!/usr/bin/perl -w
#
# Page.t:
# Tests for the Page functions
#
#  Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: louise@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Page.t,v 1.2 2009-08-26 16:52:14 louise Exp $
#

use strict;
use warnings; 
use Test::More tests => 4;
use Test::Exception; 

use FindBin;
use lib "$FindBin::Bin";
use lib "$FindBin::Bin/../perllib";
use lib "$FindBin::Bin/../../perllib";

use Page;
use MockQuery;
use mySociety::Locale;

sub mock_query(){
    my $q  = new MockQuery('mysite');
    return $q;
}

sub test_header(){
    my $q = mock_query();
    my $html;
    my %params = (title => 'test title');
    mySociety::Locale::negotiate_language('en-gb,English,en_GB');
    mySociety::Locale::gettext_domain('FixMyStreet');	
    mySociety::Locale::change();

    # Test that param that isn't explicitly allowed raises error
    $params{'test-param'} = 'test';
    throws_ok { Page::header($q, %params); } qr/bad parameter/, 'bad parameter caught ok';
    delete $params{'test-param'};

    # Test that template passed is rendered 
    $params{'template'} = 'test';    
    $html = Page::template_header('My test title', 'test', $q, 'en-gb', '/../t/templates/');	
    like  ($html, qr/My test header template/, 'named template rendered ok');
 

    return 1;
}

sub test_footer(){
    return 1;
}

ok(test_footer() == 1, 'Ran all tests for the footer function');
ok(test_header() == 1, 'Ran all tests for the header function'); 
