#!/usr/bin/perl -w -I../perllib

# json.cgi:
# A small JSON API for FixMyStreet
#
# Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: louise@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: json.cgi,v 1.4 2010-01-20 11:31:26 matthew Exp $

use strict;
use Error qw(:try);
use JSON;
use Standard;
 
sub main {
    my $q = shift;
    my $problems;
    my $type = $q->param('type') || '';
    my $start_date = $q->param('start_date') || '';
    my $end_date = $q->param('end_date') || '';
    my $category = $q->param('category') || '';
    if ($start_date !~ /^\d{4}-\d\d-\d\d$/ || $end_date !~ /^\d{4}-\d\d-\d\d$/) {
        $problems = { error => 'Invalid dates supplied' };
    } elsif ($type eq 'new_problems') {
        $problems = Problems::created_in_interval($start_date, $end_date, $category);
    } elsif ($type eq 'fixed_problems') {
        $problems = Problems::fixed_in_interval($start_date, $end_date, $category);
    }
    print $q->header( -type => 'application/json; charset=utf-8' );
    print JSON::to_json($problems);
}


Page::do_fastcgi(\&main);

