#!/usr/bin/perl -w

# CronFns.pm:
# Shared functions for cron-run scripts
#
# Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: CronFns.pm,v 1.1 2009-07-10 15:17:29 matthew Exp $

package CronFns;

use strict;
require 5.8.0;

# Horrible boilerplate to set up appropriate library paths.
use FindBin;
use lib "$FindBin::Bin/../perllib";
use lib "$FindBin::Bin/../commonlib/perllib";

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
    $site = 'emptyhomes' if $base_url =~ 'emptyhomes';
    $site = 'zurich' if $base_url =~ /zurich|zueri/;
    return $site;
}

sub language {
    my $site = shift;
    if ($site eq 'emptyhomes') {
        mySociety::Locale::negotiate_language('en-gb,English,en_GB|cy,Cymraeg,cy_GB');
        mySociety::Locale::gettext_domain('FixMyStreet-EmptyHomes', 1);
    } else {
        mySociety::Locale::negotiate_language('en-gb,English,en_GB|nb,Norwegian,nb_NO'); # XXX Testing
        mySociety::Locale::gettext_domain('FixMyStreet', 1);
    }
}

1;
