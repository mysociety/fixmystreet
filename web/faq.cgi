#!/usr/bin/perl -w -I../perllib

# faq.cgi:
# FAQ page for FixMyStreet
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: faq.cgi,v 1.40 2009-05-27 13:53:53 matthew Exp $

use strict;
use Standard -db;

my $lastmodified = (stat $0)[9];

sub main {
    my $q = shift;
    print Page::header($q, title=>_('Frequently Asked Questions'));
    if ($q->{site} eq 'emptyhomes') {
        print File::Slurp::read_file("$FindBin::Bin/../templates/website/faq-eha.html");
    } else {
        print File::Slurp::read_file("$FindBin::Bin/../templates/website/faq.html");
    }
    print Page::footer($q);
}
Page::do_fastcgi(\&main, $lastmodified);

