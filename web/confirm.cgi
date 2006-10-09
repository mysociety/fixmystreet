#!/usr/bin/perl -w

# confirm.cgi:
# Confirmation code for Neighbourhood Fix-It
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: confirm.cgi,v 1.4 2006-10-09 15:29:52 matthew Exp $

use strict;
require 5.8.0;

# Horrible boilerplate to set up appropriate library paths.
use FindBin;
use lib "$FindBin::Bin/../perllib";
use lib "$FindBin::Bin/../../perllib";

use Page;
use mySociety::AuthToken;
use mySociety::Config;
use mySociety::DBHandle qw(dbh select_all);

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

    my $out = '';
    my $token = $q->param('token');
    my $type = $q->param('type');
    my $id = mySociety::AuthToken::retrieve($type, $token);
    if ($id) {
        if ($type eq 'update') {
            dbh()->do("update comment set state='confirmed' where id=?", {}, $id);
            my $id = dbh()->selectrow_array("select problem_id from comment where id=?", {}, $id);
            $out = <<EOF;
<p>You have successfully confirmed your update and you can now <a href="/?id=$id">view it on the site</a>.</p>
EOF
        } elsif ($type eq 'problem') {
            dbh()->do("update problem set state='confirmed' where id=?", {}, $id);
            my $pc = dbh()->selectrow_array("select postcode from problem where id=?", {}, $id);
            $out = <<EOF;
<p>You have successfully confirmed your problem and you can now <a href="/?id=$id;pc=$pc">view it on the site</a>.</p>
EOF
        }
        dbh()->commit();
    } else {
        $out = <<EOF;
<p>Thank you for trying to confirm your update or problem. We seem to have a
problem ourselves though, so <a href="/contact">please let us know what went on</a>
and we'll look into it.
EOF
    }

    print Page::header($q, 'Confirmation');
    print $out;
    print Page::footer();
}
Page::do_fastcgi(\&main);

