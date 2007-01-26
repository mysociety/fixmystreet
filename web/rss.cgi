#!/usr/bin/perl -w

# rss.cgi:
# RSS for Neighbourhood Fix-It
#
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: rss.cgi,v 1.1 2007-01-26 01:01:23 matthew Exp $

use strict;
require 5.8.0;

# Horrible boilerplate to set up appropriate library paths.
use FindBin;
use lib "$FindBin::Bin/../perllib";
use lib "$FindBin::Bin/../../perllib";
use URI::Escape;

use Page;
use mySociety::Config;
use mySociety::DBHandle qw(dbh);
use mySociety::Alert;
use mySociety::Web;

BEGIN {
    mySociety::Config::set_file("$FindBin::Bin/../conf/general");
    mySociety::DBHandle::configure(
        Name => mySociety::Config::get('BCI_DB_NAME'),
        User => mySociety::Config::get('BCI_DB_USER'),
        Password => mySociety::Config::get('BCI_DB_PASS'),
        Host => mySociety::Config::get('BCI_DB_HOST', undef),
        Port => mySociety::Config::get('BCI_DB_PORT', undef)
    );
}

sub main {
    my $q = shift;
    my $type = $q->param('type') || '';
    my $choose = $q->param('choose');
    if ($choose) {
        print Page::header($q, 'Choose RSS feed');
	my $url = $ENV{SCRIPT_URI};
	$url = uri_escape($url);
	print <<EOF;
<ul>
<li><a href="http://www.bloglines.com/sub?url=$url">Bloglines</a>
<li><a href="http://google.com/reader/view/feed/$url">Google Reader</a>
<li><a href="http://add.my.yahoo.com/content?url=$url">My Yahoo!</a>
<li><a href="http://my.msn.com/addtomymsn.armx?id=rss&ut=$url&tt=CENTRALDIRECTORY&ru=http://rss.msn.com">My MSN</a>
<li><a href="http://127.0.0.1:5335/system/pages/subscriptions?url=$url">Userland</a>
<li><a href="http://127.0.0.1:8888/index.html?add_url=$url">Amphetadesk</a>
<li><a href="http://www.feedmarker.com/admin.php?do=add_feed&url=$url">Feedmarker</a>
<li><a href="$ENV{SCRIPT_URL}">Plain RSS</a>
</ul>
EOF
	print Page::footer();
	return;
    }
    if ($type eq 'local_problems') {
        my $x = ($q->param('x') * 5000 / 31);
        my $y = ($q->param('y') * 5000 / 31);
        mySociety::Alert::generate_rss($type, $x, $y);
    } elsif ($type eq 'new_updates') {
        my $id = $q->param('id');
        mySociety::Alert::generate_rss($type, $id);
    } elsif ($type eq 'new_problems') {
        mySociety::Alert::generate_rss($type);
    } else {
        throw Error::Simple('Unknown alert type') unless $type;
    }
}
Page::do_fastcgi(\&main);

