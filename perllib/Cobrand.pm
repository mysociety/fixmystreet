#!/usr/bin/perl -w
#
# Cobrand.pm:
# Cobranding for FixMyStreet.
#
#
# Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: louise@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: Cobrand.pm,v 1.58 2010-01-06 12:33:25 louise Exp $

package Cobrand;
use strict;
use Carp;
use FixMyStreet::Util;

=item get_allowed_cobrands

Return an array reference of allowed cobrand subdomains

=cut
sub get_allowed_cobrands {
    my $allowed_cobrand_string = mySociety::Config::get('ALLOWED_COBRANDS');
    my @allowed_cobrands = split(/\|/, $allowed_cobrand_string);
    return \@allowed_cobrands;
}

# Cobrand calling functions
my %fns = (
    # Return a site restriction clause and a site key if the cobrand uses a subset of the FixMyStreet
    # data. Parameter is any extra data the cobrand needs. Returns an empty string and site key 0
    # if the cobrand uses all the data.
    'site_restriction' => { default => '["", 0]' },
    # Return a contact restriction clause if the cobrand uses a subset of the FixMyStreet contact data.
    'contact_restriction' => { default => "''" },
    # Return the base url to use in links in emails for the cobranded version of the site, parameter is extra data.
    'base_url_for_emails' => { default => 'base_url($cobrand)' },
    # Base URL for the admin interface.
    'admin_base_url' => { default => '0' },
    # URL for writetothem; parameter is COBRAND_DATA.
    'writetothem_url' => { default => '0' },
    # Return the base url for the cobranded version of the site
    'base_url' => { default => "mySociety::Config::get('BASE_URL')" },
    # Return the text that prompts the user to enter their postcode/place name. Parameter is QUERY
    'enter_postcode_text' => { default => '""' },
    # Set the language and domain of the site based on the cobrand and host
    'set_lang_and_domain' => { default => '\&default_set_lang_and_domain' },
    # Return HTML for a list of alert options for the cobrand, given QUERY and OPTIONS.
    'alert_list_options' => { default => '0' },
    # Return N recent photos. If EASTING, NORTHING and DISTANCE are supplied, the photos must be attached to problems
    # within DISTANCE of the point defined by EASTING and NORTHING.
    'recent_photos' => { default => '\&Problems::recent_photos' },
    # Return recent problems on the site.
    'recent' => { default => '\&Problems::recent' },
    # Given a QUERY, return a block of html for showing front stats for the site
    'front_stats' => { default => '\&Problems::front_stats' },
    # Given a STRING ($_[1]) representing a location and a QUERY, return a string that
    # includes any disambiguating information available
    'disambiguate_location' => { default => '"$_[1]&gl=uk"' },
    # Parameter is EPOCHTIME
    'prettify_epoch' => { default => '0' },
    # Parameters are FORM_NAME, QUERY. Return HTML for any extra needed elements for FORM_NAME
    'form_elements' => { default => "''" },
    # Parameter is UPDATE_DATA, a reference to a hash of non-cobranded update data. Return cobrand extra data for the update
    'cobrand_data_for_generic_update' => { default => "''" },
    # Parameter is PROBLEM_DATA, a reference to a hash of non-cobranded problem data. Return cobrand extra data for the problem
    'cobrand_data_for_generic_problem' => { default => "''" },
    # Parameter is QUERY. Return a string of extra data to be stored with a problem
    'extra_problem_data' => { default => "''" },
    # Parameter is QUERY. Return a string of extra data to be stored with an update
    'extra_update_data' => { default => "''" },
    # Parameter is QUERY. Return a string of extra data to be stored with an alert
    'extra_alert_data' => { default => "''" },
    # Given a QUERY, extract any extra data required by the cobrand
    'extra_data' => { default => "''" },
    # Given a QUERY, return a hash of extra params to be included in
    # any URLs in links produced on the page returned by that query.
    'extra_params' => { default => "''" },
    # Returns any extra text to be displayed with a PROBLEM.
    'extra_problem_meta_text' => { default => "''" },
    # Returns any extra text to be displayed with an UPDATE.
    'extra_update_meta_text' => { default => "''" },
    # Given a URL ($_[1]), QUERY, EXTRA_DATA, return a URL with any extra params needed appended to it.
    'url' => { default => '$_[1]' },
    # Return any params to be added to responses
    'header_params' => { default => '{}' },
    # Parameter is QUERY. Return some js to set the root path from which AJAX
    # queries should be made.
    'root_path_js' => { default => "'var root_path = \"\";'" },
    # Return the title to be used in page heads.
    'site_title' => { default => "''" },
    # Return the maximum number of items to be given in the list of reports on the map
    'on_map_list_limit' => { default => 'undef' },
    # Return a boolean indicating whether the cobrand allows photo uploads
    'allow_photo_upload' => { default => '1' },
    # Return a boolean indicating whether the cobrand allows the display of crosssell adverts
    'allow_crosssell_adverts' => { default => '1' },
    # Return a boolean indicating whether the cobrand allows photo display
    'allow_photo_display' => { default => '1' },
    # Return a boolean indication whether users should see links next to updates allowing them
    # to report them as offensive.
    'allow_update_reporting' => { default => '0' },
    # Parameters are LOCATION, QUERY. Return a boolean indicating whether the
    # string LOCATION passes the cobrands checks.
    'geocoded_string_check' => { default => '1' },
    # Paramters are COUNCILS, QUERY, CONTEXT. Return a boolean indicating whether
    # COUNCILS pass any extra checks. CONTEXT is where we are on the site.
    'council_check' => { default => "[1, '']" },
    # Return an XSL to be used in rendering feeds
    'feed_xsl' => { default => "'/xsl.xsl'" },
    # Return a boolean indicating whether the cobrand displays a report of all councils
    'all_councils_report' => { default => '1' },
    # Return a boolean indicating whether people should be asked whether this
    # is the first time they've reported a problem.
    'ask_ever_reported' => { default => '1' },
    # List of names of pages to display on the admin interface
    'admin_pages' => { default => '0' },
    # Show the problem creation graph in the admin interface
    'admin_show_creation_graph' => { default => '1' },
    # The MaPit types this site handles
    'area_types' => { default => '[qw(DIS LBO MTD UTA CTY COI)]' },
    'area_min_generation' => { default => '10' },
    # Some cobrands that use a Tilma map have a smaller mid-point to make pin centred
    'tilma_mid_point' => { default => '""' },
    # Information derived from the location of the map pin
    'find_closest' => { default => '\&FixMyStreet::Util::find_closest' },
);

foreach (keys %fns) {
    die "Default must be specified for $_" unless $fns{$_}{default} ne '';
    eval <<EOF;
sub $_ {
    my (\$cobrand, \@args) = \@_;
    return call(\$cobrand, '$_', $fns{$_}{default}, \@args);
}
EOF
}

# This is the main Cobrand calling function that sees if the Cobrand handles
# the function and responds appropriately.
sub call {
    my ($cobrand, $fn, $default, @args) = @_;
    return call_default($default, @args) unless $cobrand;
    my $handle = cobrand_handle($cobrand);
    return call_default($default, @args) unless $handle && $handle->can($fn);
    return $handle->$fn(@args);
}

# If we're not in a Cobrand, or the Cobrand module doesn't offer a function,
# this function works out how to return the default response
sub call_default {
    my ($default, @args) = @_;
    return $default unless ref $default;
    return @$default if ref $default eq 'ARRAY'; # Arrays passed back as values
    return $default if ref $default eq 'HASH'; # Hashes passed back as reference
    return $default->(@args) if ref $default eq 'CODE'; # Functions are called.
    die "Default of $default treatment unknown";
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

# Cobrand functions to fetch config variables
%fns = (
    # Return the contact name for the cobranded version of the site
    # (to be used in emails).
    'contact_name' => 'CONTACT_NAME',
    # Return the contact email for the cobranded version of the site
    'contact_email' => 'CONTACT_EMAIL',
);

foreach (keys %fns) {
    eval <<EOF;
sub $_ {
    my \$cobrand = shift;
    return get_cobrand_conf(\$cobrand, '$fns{$_}');
}
EOF
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

=item email_host COBRAND

Return the virtual host that sends email for this cobrand

=cut

sub email_host {
    my ($cobrand) = @_;
    my $email_vhost = mySociety::Config::get('EMAIL_VHOST');
    if ($cobrand) {
        $email_vhost = mySociety::Config::get('EMAIL_VHOST_'. uc($cobrand), $email_vhost);
    }
    if ($email_vhost && 'http://' . $email_vhost eq mySociety::Config::get('BASE_URL')) {
        return 1;
    } else {
        return 0;
    }
}

# Default things to do for the set_lang_and_domain call
sub default_set_lang_and_domain {
    my ($lang, $unicode) = @_;
    mySociety::Locale::negotiate_language('en-gb,English,en_GB|nb,Norwegian,nb_NO', $lang); # XXX Testing
    mySociety::Locale::gettext_domain('FixMyStreet', $unicode);
    mySociety::Locale::change();
}

1;

