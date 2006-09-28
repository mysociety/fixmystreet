#!/usr/bin/perl -w

# proxy.cgi:
# I hate everthing.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: proxy.cgi,v 1.1 2006-09-28 00:01:42 matthew Exp $

use strict;
require 5.8.0;
# Horrible boilerplate to set up appropriate library paths.
use FindBin;
use lib "$FindBin::Bin/../perllib";
use lib "$FindBin::Bin/../../perllib";
use LWP::Simple;
use Page;
use mySociety::Config;

BEGIN {
    mySociety::Config::set_file("$FindBin::Bin/../conf/general");
}

sub main {
    my $q = shift;
    print $q->header('text/javascript');
    my $x = $q->param('x') || 0; $x += 0;
    my $y = $q->param('y') || 0; $y += 0;
    my $xm = $q->param('xm') || 0; $xm += 0;
    my $ym = $q->param('ym') || 0; $ym += 0;
    return unless $x && $y && $xm && $ym;
    
    my $url = mySociety::Config::get('TILES_URL');
    my $tiles_url = "$url$x-$xm,$y-$ym/JSON";
    my $tiles = LWP::Simple::get($tiles_url);
    print $tiles;
}
Page::do_fastcgi(\&main);
