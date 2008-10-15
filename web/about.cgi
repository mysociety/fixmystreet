#!/usr/bin/perl -w -I../perllib

# about.cgi:
# For EHA
#
# Copyright (c) 2008 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: about.cgi,v 1.8 2008-10-15 22:07:26 matthew Exp $

use strict;
use Standard -db;

my $lastmodified = (stat $0)[9];

# Main code for index.cgi
sub main {
    my $q = shift;
    print Page::header($q, title=>'About us');
    print <<ABOUTUS if $q->{site} eq 'emptyhomes';
<h1>The Empty Homes Agency</h1>
<p>The Empty Homes agency is an independent campaigning charity. We are not
part of government, and have no formal links with local councils although we
work in cooperation with both. We exist to highlight the waste of empty
property and work with others to devise and promote sustainable solutions to
bring empty property back into use. We are based in London but work across
England. We also work in partnership with other charities across the UK.</p>
ABOUTUS
    print Page::footer($q);
}
Page::do_fastcgi(\&main, $lastmodified);

