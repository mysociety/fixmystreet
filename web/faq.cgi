#!/usr/bin/perl -w -I../perllib

# faq.cgi:
# FAQ page for FixMyStreet
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: faq.cgi,v 1.42 2009-07-10 16:10:22 matthew Exp $

use strict;
use Standard -db;
use mySociety::Locale;

my $lastmodified = (stat $0)[9];
sub main {
    my $q = shift;
    print Page::header($q, title=>_('Frequently Asked Questions'));
    my $lang = $mySociety::Locale::lang;
    print Page::template_include("faq-$lang", $q, Page::template_root($q));
    print Page::footer($q);
}
Page::do_fastcgi(\&main, $lastmodified);

