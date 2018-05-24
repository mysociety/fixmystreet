# CronFns.pm:
# Shared functions for cron-run scripts
#
# Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org

package CronFns;

use strict;
require 5.8.0;

use mySociety::Locale;

sub options {
    die "Either no arguments, --nomail or --verbose" if (@ARGV>1);
    my $nomail = 0;
    my $verbose = 0;
    my $debug = 0;
    $nomail = 1 if (@ARGV==1 && $ARGV[0] eq '--nomail');
    $verbose = 1 if (@ARGV==1 && $ARGV[0] eq '--verbose');
    $debug = 1 if (@ARGV==1 && $ARGV[0] eq '--debug');
    $verbose = 1 if $nomail;
    return ($verbose, $nomail, $debug);
}

sub site {
    my $base_url = shift;
    my $site = 'fixmystreet';
    $site = 'fixamingata' if $base_url =~ /fixamingata/;
    $site = 'zurich' if $base_url =~ /zurich|zueri/;
    $site = 'smidsy' if $base_url =~ /smidsy|collideosco/;
    $site = 'kiitc' if $base_url =~ /kiitc|acv|keepitinthecommunity/;
    return $site;
}

sub language {
    my $site = shift;
    mySociety::Locale::negotiate_language('en-gb,English,en_GB|nb,Norwegian,nb_NO'); # XXX Testing
    mySociety::Locale::gettext_domain('FixMyStreet', 1);
}

1;
