#!/usr/bin/perl -w
#
# Page.t:
# Tests for the Page functions
#
#  Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: louise@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Page.t,v 1.5 2009-09-15 18:00:39 louise Exp $
#

use strict;
use warnings; 
use Test::More tests => 15;
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

sub set_lang($) {
    my $lang = shift;
    mySociety::Locale::negotiate_language($lang);
    mySociety::Locale::gettext_domain('FixMyStreet');
    mySociety::Locale::change();
}

sub test_geocode_string() {
    my %params = ();
    my $q = new MockQuery('nosite', \%params);
    
    # geocode a straightforward string, expect success 
    my ($x, $y, $easting, $northing, $error) = Page::geocode_string('Buckingham Palace', $q);
    ok($x == 3279, 'example x coordinate generated') or diag("Got $x");
    ok($y == 1113, 'example y coordinate generated') or diag("Got $y");;
    ok($easting == 529044, 'example easting generated') or diag("Got $easting");
    ok($northing == 179619, 'example northing generated') or diag("Got $northing");
    ok(! defined($error), 'should not generate error for simple example') or diag("Got $error");
    # expect a failure message for Northern Ireland
    ($x, $y, $easting, $northing, $error) = Page::geocode_string('Falls Road, Belfast', $q);
    ok($error eq "We do not cover Northern Ireland, I'm afraid, as our licence doesn't include any maps for the region.", 'error message produced for NI location') or diag("Got $error");
}

sub test_header() {
    my $q = mock_query();
    my $html;
    my %params = (title => 'test title');
    set_lang('en-gb,English,en_GB');
   
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
ok(test_footer() == 1, 'Ran all tests for the footer function');
ok(test_header() == 1, 'Ran all tests for the header function'); 
ok(test_geocode_string() == 1, 'Ran all tests for the geocode_string function');
