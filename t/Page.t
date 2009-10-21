#!/usr/bin/perl -w
#
# Page.t:
# Tests for the Page functions
#
#  Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: louise@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Page.t,v 1.7 2009-10-21 16:09:22 louise Exp $
#

use strict;
use warnings; 
use Test::More tests => 22;
use Test::Exception; 

use FindBin;
use lib "$FindBin::Bin";
use lib "$FindBin::Bin/../perllib";
use lib "$FindBin::Bin/../../perllib";

use Page;
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

sub test_apply_on_map_list_limit {
   my @original_on_map = ('a', 'b', 'c', 'd', 'e', 'f');
   my @original_around_map = ('g', 'h', 'i', 'j', 'k');
   my $limit = undef;
   
   my ($on_map, $around_map) = Page::apply_on_map_list_limit(\@original_on_map, \@original_around_map, $limit);
   is_deeply($on_map, \@original_on_map, 'On map list should be returned unaltered if no limit is given');
   is_deeply($around_map, \@original_around_map, 'Around map list should be returned unaltered if no limit is given');

   $limit = 20;
   ($on_map, $around_map) = Page::apply_on_map_list_limit(\@original_on_map, \@original_around_map, $limit);
   is_deeply($on_map, \@original_on_map, 'On map list should be returned unaltered if the limit is higher than the size of the on map list') or diag("Got @$on_map for @original_on_map");
   is_deeply($around_map, \@original_around_map, 'Around map list should be returned unaltered if the limit is higher than the size of the on map list') or diag("Got @$around_map");

   $limit = 3;
   ($on_map, $around_map) = Page::apply_on_map_list_limit(\@original_on_map, \@original_around_map, $limit);
   my @expected_on_map = ('a', 'b' ,'c');
   my @expected_around_map = ( 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k');
   is_deeply($on_map, \@expected_on_map, 'On map list is cropped to limit size') or diag("Got @$on_map");
   is_deeply($around_map, \@expected_around_map, 'Around map list has extra items prepended') or diag("Got ");

}

ok(test_base_url_with_lang() == 1, 'Ran all tests for base_url_with_lang');
ok(test_footer() == 1, 'Ran all tests for the footer function');
ok(test_header() == 1, 'Ran all tests for the header function'); 
ok(test_geocode_string() == 1, 'Ran all tests for the geocode_string function');
ok(test_apply_on_map_list_limit() == 1, 'Ran all tests for apply_on_map_list_limit');
