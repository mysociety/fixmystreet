#!/usr/bin/perl -w -I../perllib

# test.cgi
# Part of test suite to force an error to check error handling works.
#
# Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: test.cgi,v 1.1 2009-07-15 20:51:21 matthew Exp $

use strict;
use Standard;

sub main {
    my $q = shift;

    print $q->header(-charset => 'utf-8', -content_type => 'text/plain');
    if ($q->param('error')) {
        print 10 / 0; # Cause an error by dividing by zero.
    }
    print "Success";
}

Page::do_fastcgi(\&main);

