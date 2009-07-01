#!/usr/bin/perl -w -I../perllib

# json.cgi:
# A small JSON API for FixMyStreet
#
# Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: louise@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: json.cgi,v 1.1 2009-07-01 09:45:12 louise Exp $

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
    print $q->header( -type => 'text/html; charset=utf-8' );
    if ($type eq 'new_problems'){
        $problems = Problems::created_in_interval($start_date, $end_date);
    } elsif ($type eq 'fixed_problems') {
        $problems = Problems::fixed_in_interval($start_date, $end_date);
    }
    my $out = JSON::to_json($problems);
    print $out;  
}


Page::do_fastcgi(\&main);

