#!/usr/bin/perl -w
#
# Cobrand.pm:
# Cobranding for FixMyStreet.
#
# 
# Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: louise@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: Cobrand.pm,v 1.54 2009-12-15 17:21:08 matthew Exp $

package Cobrand;
use strict;
use Carp;

=item get_allowed_cobrands

Return an array reference of allowed cobrand subdomains

=cut
sub get_allowed_cobrands {
    my $allowed_cobrand_string = mySociety::Config::get('ALLOWED_COBRANDS');
    my @allowed_cobrands = split(/\|/, $allowed_cobrand_string);
    return \@allowed_cobrands;
}

sub call {
    my ($cobrand, $fn, $default, @args) = @_;
    return $default unless $cobrand;
    my $handle = cobrand_handle($cobrand);
    return $default unless $handle && $handle->can($fn);
    return $handle->$fn(@args);
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

=item site_restriction COBRAND COBRAND_DATA

Return a site restriction clause and a site key if the cobrand uses a subset of the FixMyStreet 
data. COBRAND_DATA is any extra data the cobrand needs. Returns an empty string and site key 0 
if the cobrand uses all the data.

=cut
sub site_restriction {
    my ($cobrand, $cobrand_data) = @_;
    my $site_restriction = '';
    my $site_id = 0;
    my $handle = cobrand_handle($cobrand);
    return ($site_restriction, $site_id) unless $handle && $handle->can('site_restriction');
    return $handle->site_restriction($cobrand_data);
}

=item contact_restriction COBRAND

Return a contact restriction clause if the cobrand uses a subset of the FixMyStreet contact data. 

=cut

sub contact_restriction { 
    my ($cobrand) = @_;
    return call($cobrand, 'contact_restriction', '');
}

=item base_url COBRAND

Return the base url for the cobranded version of the site

=cut
sub base_url {
    my $cobrand = shift;
    return mySociety::Config::get('BASE_URL') unless $cobrand;
    my $handle = cobrand_handle($cobrand);
    return mySociety::Config::get('BASE_URL') unless $handle;
    return $handle->base_url();
}

=item base_url_for_emails COBRAND

Return the base url to use in links in emails for the cobranded 
version of the site

=cut

sub base_url_for_emails {
    my ($cobrand, $cobrand_data) = @_;
    return call($cobrand, 'base_url_for_emails', base_url($cobrand), $cobrand_data);
}

=item admin_base_url COBRAND

Base URL for the admin interface.

=cut
sub admin_base_url {
    my ($cobrand) = @_;
    return call($cobrand, 'admin_base_url', 0);
}

=item writetothem_url COBRAND COBRAND_DATA

URL for writetothem

=cut
sub writetothem_url {
    my ($cobrand, $cobrand_data) = @_;
    return call($cobrand, 'writetothem_url', 0, $cobrand_data);
}

=item email_host COBRAND

Return the virtual host that sends email for this cobrand

=cut

sub email_host {
    my ($cobrand) = @_;
    my $email_vhost;
    if ($cobrand eq '') {
        $email_vhost = mySociety::Config::get('EMAIL_VHOST');
    } else { 
        $email_vhost = mySociety::Config::get('EMAIL_VHOST_'. uc($cobrand));
    }
    if ($email_vhost && 'http://' . $email_vhost eq mySociety::Config::get('BASE_URL')) {
        return 1;
    } else {
        return 0;
    }
}

=item contact_name COBRAND 

Return the contact name for the cobranded version of the site 
(to be used in emails).

=cut 
sub contact_name {
    my $cobrand = shift; 
    return get_cobrand_conf($cobrand, 'CONTACT_NAME');
}

=item contact_email COBRAND

Return the contact email for the cobranded version of the site

=cut
sub contact_email {
    my $cobrand = shift;
    return get_cobrand_conf($cobrand, 'CONTACT_EMAIL');
}

=item alert_list_options COBRAND Q OPTIONS

Return HTML for a list of alert options for the cobrand.

=cut
sub alert_list_options {
    my ($cobrand, $q, @options) = @_;
    return call($cobrand, 'alert_list_options', 0, $q, @options);
}

=item get_cobrand_conf COBRAND KEY

Get the value for KEY from the config file for COBRAND

=cut
sub get_cobrand_conf {
    my ($cobrand, $key) = @_;
    my $value; 
    if ($cobrand){
        (my $dir = __FILE__) =~ s{/[^/]*?$}{};
        if (-e "$dir/../conf/cobrands/$cobrand/general"){
            mySociety::Config::set_file("$dir/../conf/cobrands/$cobrand/general");            
            $cobrand = uc($cobrand);
            $value = mySociety::Config::get($key . "_" . $cobrand, undef);
            mySociety::Config::set_file("$dir/../conf/general");
        }
    }
    if (!defined($value)){
        $value = mySociety::Config::get($key);
    }
    return $value;
}

=item set_lang_and_domain COBRAND LANG

Set the language and domain of the site based on the cobrand and host

=cut
sub set_lang_and_domain($$;$) {
    my ($cobrand, $lang, $unicode) = @_;
    my $handle;
    if ($cobrand && ($handle = cobrand_handle($cobrand)) && $handle->can('set_lang_and_domain')) {
        $handle->set_lang_and_domain($lang, $unicode);
    } else {
        mySociety::Locale::negotiate_language('en-gb,English,en_GB|nb,Norwegian,nb_NO', $lang); # XXX Testing
        mySociety::Locale::gettext_domain('FixMyStreet', $unicode);
        mySociety::Locale::change(); 
    }
}

=item recent_photos COBRAND N [EASTING NORTHING DISTANCE]

Return N recent photos. If EASTING, NORTHING and DISTANCE are supplied, the photos must be attached to problems
within DISTANCE of the point defined by EASTING and NORTHING. 

=cut
sub recent_photos {
    my ($cobrand, $num, $e, $n, $dist) = @_;
    my $handle;
    if ($cobrand){
        $handle = cobrand_handle($cobrand); 
    }
    if ( !$cobrand || !$handle || ! $handle->can('recent_photos')){
        return Problems::recent_photos($num, $e, $n, $dist);
    } else {
        return $handle->recent_photos($num, $e, $n, $dist);
    }
}


=item recent

Return recent problems on the site. 

=cut
sub recent {
    my ($cobrand) = @_;
    my $handle;
    if ($cobrand){
        $handle = cobrand_handle($cobrand);
    }

    if ( !$cobrand || !$handle || ! $handle->can('recent') ){
        return Problems::recent();
    } else {
        return $handle->recent();
    }
}

=item front_stats

Return a block of html for showing front stats for the site

=cut

sub front_stats {
         
    my ($cobrand, $q) = @_;
    my $handle;
    if ($cobrand){
        $handle = cobrand_handle($cobrand);
    }
     
    if ( !$cobrand || !$handle || ! $handle->can('front_stats')){
        return Problems::front_stats($q);
    } else {
        return $handle->front_stats();
    }
}

=item

Return the text that prompts the user to enter their postcode/place name

=cut

sub enter_postcode_text {
    my ($cobrand, $q) = @_;
    return call($cobrand, 'enter_postcode_text', _("Enter a nearby GB postcode, or street name and area:"), $q);
}

=item disambiguate_location COBRAND S Q

Given a string representing a location, return a string that includes any disambiguating 
information available

=cut

sub disambiguate_location {
    my ($cobrand, $s, $q) = @_;
    return call($cobrand, 'disambiguate_location', $s, $s, $q);
}

=item prettify_epoch COBRAND EPOCHTIME

=cut

sub prettify_epoch {
    my ($cobrand, $epochtime) = @_;
    return call($cobrand, 'prettify_epoch', 0, $epochtime);
}

=item form_elements FORM_NAME Q

Return HTML for any extra needed elements for FORM_NAME

=cut

sub form_elements {
    my ($cobrand, $form_name, $q) = @_;
    return call($cobrand, 'form_elements', '', $form_name, $q);
}

=item extra_problem_data COBRAND Q

Return a string of extra data to be stored with a problem

=cut

sub extra_problem_data {
    my ($cobrand, $q) = @_;
    return call($cobrand, 'extra_problem_data', '', $q);
} 

=item extra_update_data COBRAND Q 

Return a string of extra data to be stored with a problem

=cut

sub extra_update_data {
    my ($cobrand, $q) = @_;
    return call($cobrand, 'extra_update_data', '', $q);
}

=item extra_alert_data COBRAND Q

Return a string of extra data to be stored with an alert

=cut
    
sub extra_alert_data {
    my ($cobrand, $q) = @_;
    return call($cobrand, 'extra_alert_data', '', $q);
}

=item extra_data COBRAND Q

Given a query Q, extract any extra data required by the cobrand 

=cut

sub extra_data {
    my ($cobrand, $q) = @_;
    return call($cobrand, 'extra_data', '', $q);
}

=item extra_params COBRAND Q 

Given a query, return a hash of extra params to be included in 
any URLs in links produced on the page returned by that query.

=cut 
sub extra_params {
    my ($cobrand, $q) = @_;
    return call($cobrand, 'extra_params', '', $q);
}

=item show_watermark

Returns a boolean indicating whether the map watermark should be displayed

=cut
sub show_watermark {
    my ($cobrand) = @_;
    return call($cobrand, 'show_watermark', 1);
}

=item extra_problem_meta_text COBRAND PROBLEM

Returns any extra text to be displayed with a problem.

=cut
sub extra_problem_meta_text {
    my ($cobrand, $problem) = @_;
    return call($cobrand, 'extra_problem_meta_text', '', $problem);
}

=item extra_update_meta_text COBRAND PROBLEM

Returns any extra text to be displayed with an update.

=cut
sub extra_update_meta_text {
    my ($cobrand, $update) = @_;
    return call($cobrand, 'extra_update_meta_text', '', $update);
}

=item url

Given a URL, return a URL with any extra params needed appended to it. 

=cut
sub url {
    my ($cobrand, $url, $q, $extra_data) = @_;
    return call($cobrand, 'url', $url, $url, $q, $extra_data);
}

=item header_params

Return any params to be added to responses

=cut 

sub header_params { 
    my ($cobrand, $q, %params) = @_;
    my $handle;
    if ($cobrand){
        $handle = cobrand_handle($cobrand);
    }
    if ( !$cobrand || !$handle || !$handle->can('header_params')){
        return {};
    } else{
        return $handle->header_params($q, %params);
    } 
}

=item root_path_js COBRAND Q
 
Return some js to set the root path from which AJAX queries should be made
based on the cobrand and current query Q
=cut 

sub root_path_js {
    my ($cobrand, $q) = @_;
    return call($cobrand, 'root_path_js', 'var root_path = "";', $q);
}

=item site_title COBRAND

Return the title to be used in page heads.

=cut
sub site_title {
    my ($cobrand) = @_; 
    return call($cobrand, 'site_title', '');
}

=item on_map_list_limit COBRAND

Return the maximum number of items to be given in the list of reports
on the map

=cut
sub on_map_list_limit {
    my ($cobrand) = @_;
    return call($cobrand, 'on_map_list_limit', undef);
}

=item allow_photo_upload COBRAND

Return a boolean indicating whether the cobrand allows photo uploads

=cut

sub allow_photo_upload {
    my ($cobrand) = @_;
    return call($cobrand, 'allow_photo_upload', 1);
}

=item allow_crosssell_adverts COBRAND

Return a boolean indicating whether the cobrand allows the display of crosssell adverts

=cut
sub allow_crosssell_adverts {
    my ($cobrand) = @_;
    return call($cobrand, 'allow_crosssell_adverts', 1);
}

=item allow_photo_display COBRAND

Return a boolean indicating whether the cobrand allows photo display

=cut 

sub allow_photo_display {
    my ($cobrand) = @_;
    return call($cobrand, 'allow_photo_display', 1);
}

=item allow_update_reporting COBRAND

Return a boolean indication whether users should see links next to updates allowing them
to report them as offensive. 

=cut 

sub allow_update_reporting {
    my ($cobrand) = @_;
    return call($cobrand, 'allow_update_reporting', 0);
}

=item geocoded_string_check LOCATION QUERY

Return a boolean indicating whether the string LOCATION passes the cobrands
checks.

=cut
sub geocoded_string_check {
    my ($cobrand, $location, $query) = @_;
    return call($cobrand, 'geocoded_string_check', 1, $location, $query);
}

=item council_check COBRAND COUNCILS QUERY

Return a boolean indicating whether the councils for the location passed any extra checks defined by the cobrand
using data in the query
=cut
sub council_check {
    my ($cobrand, $councils, $query, $context) = @_;
    my $handle;
    if ($cobrand){
        $handle = cobrand_handle($cobrand);
    }
    if ( !$cobrand || !$handle || !$handle->can('council_check')){
        return (1, '');
    } else{
        return $handle->council_check($councils, $query, $context);
    }
} 

=item feed_xsl COBRAND
 
Return an XSL to be used in rendering feeds

=cut
sub feed_xsl {
    my ($cobrand) = @_;
    return call($cobrand, 'feed_xsl', '/xsl.xsl');
}

=item all_councils_report COBRAND

Return a boolean indicating whether the cobrand displays a report of all councils

=cut

sub all_councils_report {
    my ($cobrand) = @_;
    return call($cobrand, 'all_councils_report', 1);
}

=item ask_ever_reported 

Return a boolean indicating whether people should be asked whether this
is the first time they've reported a problem.

=cut

sub ask_ever_reported {
    my ($cobrand) = @_;
    return call($cobrand, 'ask_ever_reported', 1);
}

=item admin_pages COBRAND

List of names of pages to display on the admin interface 

=cut
sub admin_pages {
    my ($cobrand) = @_;
    return call($cobrand, 'admin_pages', 0);
}

=item admin_show_creation_graph COBRAND

Show the problem creation graph in the admin interface
=cut
sub admin_show_creation_graph {
    my ($cobrand) = @_;
    return call($cobrand, 'admin_show_creation_graph', 1);
}

1;

