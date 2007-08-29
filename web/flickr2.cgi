#!/usr/bin/perl -w -I../perllib

# flickr2.cgi:
# Check photo details, and confirm for council
#
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: flickr2.cgi,v 1.3 2007-08-29 23:03:16 matthew Exp $

use strict;
use Standard;
use URI::Escape;
use mySociety::AuthToken;
use mySociety::Email;
use mySociety::EmailUtil;

sub main {
    my $q = shift;
    my $out = '';
    if (my $token = $q->param('token')) {
        my $id = mySociety::AuthToken::retrieve('flickr', $token);
        if ($id) {
            my ($e, $n, $name, $email, $title) = dbh()->selectrow_array(
                "select easting,northing,name,email,title from problem where id=? and state='flickr'", {}, $id);
            if ($email) {
                $name = uri_escape($name);
                $email = uri_escape($email);
                $title = uri_escape($title);
		# XXX: Look up some of this stuff at the destination instead???
                print $q->redirect("/?flickr=$token;submit_map=1;easting=$e;northing=$n;name=$name;email=$email;title=$title;anonymous=1");
                return;
            }
            $out = $q->p("That report appears to have been checked already.");
        } else {
            $out = $q->p(_(<<EOF));
Thank you for trying to register for your Flickr photos. We seem to have a
problem ourselves though, so <a href="/contact">please let us know what went on</a>
and we'll look into it.
EOF
        }
    } else {
        $out .= $q->p('You need a token to get to this page!');
    }

    print Page::header($q, title=>'Flickr photo upload');
    print $out;
    print Page::footer();
}
Page::do_fastcgi(\&main);
