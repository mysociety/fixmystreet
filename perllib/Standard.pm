#!/usr/bin/perl
#
# Standard.pm:
# Common headers for Perl files. Mostly in the main namespace on purpose
# (Filter::Macro sadly didn't work, CPAN bug #20494)
#
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Standard.pm,v 1.3 2009-09-15 13:57:01 louise Exp $

use strict;
use warnings;
require 5.8.0;

# Horrible boilerplate to set up appropriate library paths.
use FindBin;
use lib "$FindBin::Bin/../perllib";
use lib "$FindBin::Bin/../commonlib/perllib";

use Page;
use FixMyStreet::Map;

package Standard;

sub import {
    my $package = shift;
    my $db = shift;
    unless ($db && $db eq '-db') {
        use mySociety::Config;
        use mySociety::DBHandle qw(dbh);
        (my $file = __FILE__) =~ s{/[^/]*?$}{};
        mySociety::Config::set_file("$file/../conf/general");
        mySociety::DBHandle::configure(
            Name => mySociety::Config::get('BCI_DB_NAME'),
            User => mySociety::Config::get('BCI_DB_USER'),
            Password => mySociety::Config::get('BCI_DB_PASS'),
            Host => mySociety::Config::get('BCI_DB_HOST', undef),
            Port => mySociety::Config::get('BCI_DB_PORT', undef)
        );
        *main::dbh = \&dbh;
    }
}
