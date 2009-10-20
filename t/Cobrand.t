#!/usr/bin/perl -w
#
# Cobrand.t:
# Tests for the cobranding functions
#
#  Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: louise@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Cobrand.t,v 1.20 2009-10-20 11:55:50 louise Exp $
#

use strict;
use warnings;
use Test::More tests => 62;
use Test::Exception;

use FindBin;
use lib "$FindBin::Bin";
use lib "$FindBin::Bin/../perllib";
use lib "$FindBin::Bin/../../perllib";

use Cobrand;
use MockQuery;

sub test_site_restriction { 
    my $q  = new MockQuery('mysite');
    my ($site_restriction, $site_id) = Cobrand::set_site_restriction($q);
    like($site_restriction, qr/ and council = 1 /, 'should return result of cobrand module site_restriction function');
    ok($site_id == 99, 'should return result of cobrand module site_restriction function');    
    
    $q = new MockQuery('nosite');
    ($site_restriction, $site_id) = Cobrand::set_site_restriction($q);
    ok($site_restriction eq '', 'should return "" and zero if no module exists' );
    ok($site_id == 0, 'should return "" and zero if no module exists');
}

sub test_form_elements {
    my $q  = new MockQuery('mysite');
    my $element_html = Cobrand::form_elements('mysite', 'postcodeForm', $q);
    ok($element_html eq 'Extra html', 'should return result of cobrand module element_html function') or diag("Got $element_html");

    $element_html = Cobrand::form_elements('nosite', 'postcodeForm', $q);
    ok($element_html eq '', 'should return an empty string if no cobrand module exists') or diag("Got $element_html");
}

sub test_disambiguate_location {
    my $q  = new MockQuery('mysite');
    my $s = 'London Road';
    $s = Cobrand::disambiguate_location('mysite', $s, $q);
    ok($s eq 'Specific Location', 'should return result of cobrand module disambiguate_location function') or diag("Got $s");;
    
    $q = new MockQuery('nosite');
    $s = 'London Road';
    $s = Cobrand::disambiguate_location('nosite', $s, $q);
    ok($s eq 'London Road', 'should return location string as passed if no cobrand module exists') or diag("Got $s");
  
}

sub test_cobrand_handle {
    my $cobrand = 'mysite';
    my $handle = Cobrand::cobrand_handle($cobrand);
    like($handle->site_name(), qr/mysite/, 'should get a module handle if Util module exists for cobrand');
    $cobrand = 'nosite';    
    $handle = Cobrand::cobrand_handle($cobrand);
    ok($handle == 0, 'should return zero if no module exists');
}

sub test_cobrand_page {
    my $q  = new MockQuery('mysite');
    # should get the result of the page function in the cobrand module if one exists
    my ($html, $params) = Cobrand::cobrand_page($q);
    like($html, qr/A cobrand produced page/, 'cobrand_page returns output from cobrand module'); 

    # should return 0 if no cobrand module exists
    $q  = new MockQuery('mynonexistingsite');
    ($html, $params) = Cobrand::cobrand_page($q);
    is($html, 0, 'cobrand_page returns 0 if there is no cobrand module'); 
    return 1;

}

sub test_extra_problem_data {
    my $cobrand = 'mysite'; 
    my $q = new MockQuery($cobrand);
   
    # should get the result of the page function in the cobrand module if one exists
    my $cobrand_data = Cobrand::extra_problem_data($cobrand, $q);
    ok($cobrand_data eq 'Cobrand problem data', 'extra_problem_data should return data from cobrand module') or diag("Got $cobrand_data");

    # should return an empty string if no cobrand module exists
    $q = new MockQuery('nosite');
    $cobrand_data = Cobrand::extra_problem_data('nosite', $q);
    ok($cobrand_data eq '', 'extra_problem_data should return an empty string if there is no cobrand module') or diag("Got $cobrand_data");
}

sub test_extra_update_data {
    my $cobrand = 'mysite';
    my $q = new MockQuery($cobrand);
   
    # should get the result of the page function in the cobrand module if one exists
    my $cobrand_data = Cobrand::extra_update_data($cobrand, $q);
    ok($cobrand_data eq 'Cobrand update data', 'extra_update_data should return data from cobrand module') or diag("Got $cobrand_data");

    # should return an empty string if no cobrand module exists
    $q = new MockQuery('nosite');
    $cobrand_data = Cobrand::extra_update_data('nosite', $q);
    ok($cobrand_data eq '', 'extra_update_data should return an empty string if there is no cobrand module') or diag("Got $cobrand_data");
}


sub test_extra_alert_data {
    my $cobrand = 'mysite';
    my $q = new MockQuery($cobrand);

    # should get the result of the page function in the cobrand module if one exists
    my $cobrand_data = Cobrand::extra_alert_data($cobrand, $q);
    ok($cobrand_data eq 'Cobrand alert data', 'extra_alert_data should return data from cobrand module') or diag("Got $cobrand_data");

    # should return an empty string if no cobrand module exists
    $q = new MockQuery('nosite');
    $cobrand_data = Cobrand::extra_alert_data('nosite', $q);
    ok($cobrand_data eq '', 'extra_alert_data should return an empty string if there is no cobrand module') or diag("Got $cobrand_data");
}

sub test_base_url {
    my $cobrand = 'mysite';

    # should get the result of the page function in the cobrand module if one exists
    my $base_url = Cobrand::base_url($cobrand);
    is('http://mysite.example.com', $base_url, 'base_url returns output from cobrand module');

    # should return the base url from the config if there is no cobrand module
    $cobrand = 'nosite';
    $base_url = Cobrand::base_url($cobrand);
    is(mySociety::Config::get('BASE_URL'), $base_url, 'base_url returns config base url if no cobrand module');

}

sub test_base_url_for_emails {
    my $cobrand = 'mysite';    

    # should get the results of the base_url_for_emails function in the cobrand module if one exists
    my $base_url = Cobrand::base_url_for_emails($cobrand);
    is('http://mysite.foremails.example.com', $base_url, 'base_url_for_emails returns output from cobrand module') ;

    # should return the result of Cobrand::base_url otherwise
    $cobrand = 'nosite';
    $base_url = Cobrand::base_url_for_emails($cobrand);
    is(mySociety::Config::get('BASE_URL'), $base_url, 'base_url_for_emails returns config base url if no cobrand module');

}

sub test_extra_params { 
    my $cobrand = 'mysite';    
    my $q = new MockQuery($cobrand);

    # should get the results of the extra_params function in the cobrand module if one exists
    my $extra_params = Cobrand::extra_params($cobrand, $q);
    is($extra_params, 'key=value', 'extra_params returns output from cobrand module') ;

    # should return an empty string otherwise
    $cobrand = 'nosite';
    $extra_params = Cobrand::extra_params($cobrand, $q);
    is($extra_params, '', 'extra_params returns an empty string if no cobrand module');
    
}

sub test_header_params {
    my $cobrand = 'mysite';
    my $q = new MockQuery($cobrand);

    # should get the results of the header_params function in the cobrand module if one exists
    my $header_params = Cobrand::header_params($cobrand, $q);
    is_deeply($header_params, {'key' => 'value'}, 'header_params returns output from cobrand module') ;

    # should return an empty string otherwise
    $cobrand = 'nosite';
    $header_params = Cobrand::header_params($cobrand, $q);
    is_deeply($header_params, {}, 'header_params returns an empty hash ref if no cobrand module');
}

sub test_root_path_js {
    my $cobrand = 'mysite';
    my $root_path_js = Cobrand::root_path_js($cobrand);
 
    # should get the results of the root_path_js function in the cobrand module if one exists
    is($root_path_js, 'root path js', 'root_path_js returns output from cobrand module');

    # should return a js string setting the root path to an empty string otherwise
    $cobrand = 'nosite';
    $root_path_js = Cobrand::root_path_js($cobrand);
    is($root_path_js, 'var root_path = "";', 'root_path_pattern returns a string setting the root path to an empty string if no cobrand module');
}

sub test_site_title {
    my $cobrand = 'mysite';
    my $site_title = Cobrand::site_title($cobrand);

    # should get the results of the site_title function in the cobrand module if one exists
    is($site_title,  'Mysite Title', 'site_title returns output from cobrand module');

    # should return an empty string otherwise
    $cobrand = 'nosite';
    $site_title = Cobrand::site_title($cobrand);
    is($site_title, '', 'site_title returns an empty string if no site title');
}

sub test_on_map_list_limit {
    my $cobrand = 'mysite';
    my $limit = Cobrand::on_map_list_limit($cobrand);
   
    is($limit, 30, 'on_map_list_limit returns output from cobrand module');

    $cobrand = 'nosite';
    $limit = Cobrand::on_map_list_limit($cobrand);
    is($limit, undef, 'on_map_list_limit returns undef if there is no limit defined by the cobrand');

}

sub test_url {
    my $cobrand = 'mysite';
    my $url = Cobrand::url($cobrand, '/xyz');
    is($url, '/transformed_url', 'url returns output from cobrand module');
    
    $cobrand = 'nosite';
    $url = Cobrand::url($cobrand, '/xyz');
    is($url, '/xyz', 'url returns passed url if there is no url function defined by the cobrand'); 
}

sub test_show_watermark {
    my $cobrand = 'mysite';
    my $watermark = Cobrand::show_watermark($cobrand);
    is($watermark, 0, 'show_watermark returns output from cobrand module');

    $cobrand = 'nosite';
    $watermark = Cobrand::show_watermark($cobrand);
    is($watermark, 1, 'watermark returns 1 if there is no show_watermark function defined by the cobrand');

}

sub test_allow_photo_upload {
    my $cobrand = 'mysite';
    my $photo_upload = Cobrand::allow_photo_upload($cobrand);
    is($photo_upload, 0, 'allow_photo_upload returns output from cobrand module');

    $cobrand = 'nosite';
    $photo_upload = Cobrand::allow_photo_upload($cobrand);
    is($photo_upload, 1, 'allow_photo_upload returns 1 if there is no allow_photo_upload function defined by the cobrand');
}

sub test_allow_photo_display {
    my $cobrand = 'mysite';
    my $photo_display = Cobrand::allow_photo_display($cobrand);
    is($photo_display, 0, 'allow_photo_display returns output from cobrand module');

    $cobrand = 'nosite';
    $photo_display = Cobrand::allow_photo_display($cobrand);
    is($photo_display, 1, 'allow_photo_display returns 1 if there is no allow_photo_display function defined by the cobrand');
}

sub test_council_check {
    my $cobrand = 'mysite';
    my $councils = {};
    my $query = new MockQuery('mysite');
    my ($check_result, $error) = Cobrand::council_check($cobrand, $councils, $query);
    is($check_result, 0, 'council_check returns output from cobrand module');
    
    $cobrand = 'nosite';
    ($check_result, $error) = Cobrand::council_check($cobrand, $councils, $query);
    is($check_result, 1, 'council_check returns 1 if there is no council_check function defined by the cobrand');
}

ok(test_cobrand_handle() == 1, 'Ran all tests for the cobrand_handle function');
ok(test_cobrand_page() == 1, 'Ran all tests for the cobrand_page function');
ok(test_site_restriction() == 1, 'Ran all tests for the site_restriction function');
ok(test_base_url() == 1, 'Ran all tests for the base url');
ok(test_disambiguate_location() == 1, 'Ran all tests for disambiguate location');
ok(test_form_elements() == 1, 'Ran all tests for form_elements');
ok(test_base_url_for_emails() == 1, 'Ran all tests for base_url_for_emails');
ok(test_extra_problem_data() == 1, 'Ran all tests for extra_problem_data');
ok(test_extra_update_data() == 1, 'Ran all tests for extra_update_data');
ok(test_extra_alert_data() == 1, 'Ran all tests for extra_alert_data');
ok(test_extra_params() == 1, 'Ran all tests for extra_params');
ok(test_header_params() == 1, 'Ran all tests for header_params');
ok(test_root_path_js() == 1, 'Ran all tests for root_js');
ok(test_site_title() == 1, 'Ran all tests for site_title');
ok(test_on_map_list_limit() == 1, 'Ran all tests for on_map_list_limit');
ok(test_url() == 1, 'Ran all tests for url');
ok(test_show_watermark() == 1, 'Ran all tests for show_watermark');
ok(test_allow_photo_upload() == 1, 'Ran all tests for allow_photo_upload');
ok(test_allow_photo_display() == 1, 'Ran all tests for allow_photo_display');
ok(test_council_check() == 1, 'Ran all tests for council_check');
