#!/usr/bin/perl -w -I../perllib

# faq.cgi:
# FAQ page for FixMyStreet
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: faq.cgi,v 1.41 2009-07-10 15:00:34 matthew Exp $

use strict;
use Standard -db;
use mySociety::Locale;

my $lastmodified = (stat $0)[9];

sub main {
    my $q = shift;
    print Page::header($q, title=>_('Frequently Asked Questions'));
    if ($q->{site} eq 'emptyhomes') {
        my $lang = $mySociety::Locale::lang;
        if ($lang eq 'cy') {
            print File::Slurp::read_file("$FindBin::Bin/../templates/website/faq-eha.cy.html");
        } else {
            print File::Slurp::read_file("$FindBin::Bin/../templates/website/faq-eha.html");
        }
    } else {
        print File::Slurp::read_file("$FindBin::Bin/../templates/website/faq.html");
    }
    print Page::footer($q);
}
Page::do_fastcgi(\&main, $lastmodified);

