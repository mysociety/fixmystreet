#!/usr/bin/perl -w -I../perllib

# about.cgi:
# For EHA
#
# Copyright (c) 2008 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: about.cgi,v 1.10 2009-08-03 10:45:28 matthew Exp $

use strict;
use Standard -db;

my $lastmodified = (stat $0)[9];

# Main code for index.cgi
sub main {
    my $q = shift;
    print Page::header($q, title=>_('About us'));
    if ($q->{site} eq 'emptyhomes') {
        print $q->h1(_('About us'));
	print '<div style="float: left; width: 48%;">';
        print _(<<ABOUTUS);
<h2>The Empty Homes Agency</h2>
<p>The Empty Homes agency is an independent campaigning charity. We are not
part of government, and have no formal links with local councils although we
work in cooperation with both. We exist to highlight the waste of empty
property and work with others to devise and promote sustainable solutions to
bring empty property back into use. We are based in London but work across
England. We also work in partnership with other charities across the UK.</p>
ABOUTUS
	print '</div> <div style="float: right; width:48%;">';
        print _(<<ABOUTUS);
<h2>Shelter Cymru</h2>
Shelter Cymru is Wales&rsquo; people and homes charity and wants everyone in Wales to
have a decent home. We believe a home is a fundamental right and essential to
the health and well-being of people and communities.  We work for people in
housing need. We have offices all over Wales and prevent people from losing
their homes by offering free, confidential and independent advice. When
necessary we constructively challenge on behalf of people to ensure they are
properly assisted and to improve practice and learning. We believe that
bringing empty homes back into use can make a significant contribution to the
supply of affordable homes in Wales.
<a href="http://www.sheltercymru.org.uk/shelter/advice/pdetail.asp?cat=20">Further information about our work on
empty homes</a>.
ABOUTUS
	print '</div>';
    }
    print Page::footer($q);
}
Page::do_fastcgi(\&main, $lastmodified);

