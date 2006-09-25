#!/usr/bin/perl -w

# faq.cgi:
# FAQ page for Neighbourhood Fix-It
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: faq.cgi,v 1.1 2006-09-25 18:12:56 matthew Exp $

use strict;
require 5.8.0;

# Horrible boilerplate to set up appropriate library paths.
use FindBin;
use lib "$FindBin::Bin/../perllib";
use lib "$FindBin::Bin/../../perllib";
use Page;

# Main code for index.cgi
sub main {
    my $q = shift;
    print Page::header($q, 'FAQ');
    print faq();
    print Page::footer();
}
Page::do_fastcgi(\&main);

sub faq {
    my $out = '<div id="relativediv">';
    $out .= <<EOF;
<h1>Frequently Asked Questions</h1>
<p>FAQ stuff here</p>
</div>
EOF
    return $out;
}

