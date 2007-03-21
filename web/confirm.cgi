#!/usr/bin/perl -w

# confirm.cgi:
# Confirmation code for Neighbourhood Fix-It
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: confirm.cgi,v 1.12 2007-03-21 22:41:48 matthew Exp $

use strict;
require 5.8.0;

# Horrible boilerplate to set up appropriate library paths.
use FindBin;
use lib "$FindBin::Bin/../perllib";
use lib "$FindBin::Bin/../../perllib";
use Digest::SHA1 qw(sha1_hex);

use Page;
use mySociety::AuthToken;
use mySociety::Config;
use mySociety::DBHandle qw(dbh select_all);
use mySociety::Util qw(random_bytes);

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
            dbh()->do("update comment set state='confirmed' where id=? and state='unconfirmed'", {}, $id);
            my ($email) = dbh()->selectrow_array("select email from comment where id=?", {}, $id);
            my ($problem_id, $fixed, $reopen) = dbh()->selectrow_array("select problem_id,mark_fixed,mark_open from comment where id=?", {}, $id);
            if ($fixed) {
                dbh()->do("update problem set state='fixed' where id=? and state='confirmed'", {}, $problem_id);
            } elsif ($reopen) {
                dbh()->do("update problem set state='confirmed' where id=? and state='fixed'", {}, $problem_id);
            }
            my $salt = unpack('h*', random_bytes(8));
            my $secret = scalar(dbh()->selectrow_array('select secret from secret'));
            my $signed_email = sha1_hex("$problem_id-$email-$salt-$secret");
            $out = <<EOF;
<form action="/alert" method="post">
<p>You have successfully confirmed your update and you can now <a href="/?id=$problem_id#update_$id">view it on the site</a>.</p>
<p>You could also
<a href="/rss/$problem_id">subscribe to the RSS feed</a> of updates by other local people on this problem,
or
<input type="hidden" name="signed_email" value="$salt,$signed_email">
<input type="hidden" name="email" value="$email">
<input type="hidden" name="id" value="$problem_id">
<input type="hidden" name="type" value="updates">
<input type="submit" value="sign up"> if you wish to receive updates by email.
</p>
</form>
EOF
        } elsif ($type eq 'problem') {
            dbh()->do("update problem set state='confirmed' where id=? and state='unconfirmed'", {}, $id);
	    my ($email, $council) = dbh()->selectrow_array("select email, council from problem where id=?", {}, $id);
	    $council = $council ? ' and <strong>we will now send it to the council</strong>' : '';
            my $salt = unpack('h*', random_bytes(8));
            my $secret = scalar(dbh()->selectrow_array('select secret from secret'));
            my $signed_email = sha1_hex("$id-$email-$salt-$secret");
            $out = <<EOF;
<form action="/alert" method="post">
<p>You have successfully confirmed your problem$council.
You can <a href="/?id=$id">view the problem on this site</a>.</p>
<p>You could also
<a href="/rss/$id">subscribe to the RSS feed</a> of updates by other local people on this problem,
or
<input type="hidden" name="signed_email" value="$salt,$signed_email">
<input type="hidden" name="email" value="$email">
<input type="hidden" name="id" value="$id">
<input type="hidden" name="type" value="updates">
<input type="submit" value="sign up"> if you wish to receive updates by email.
</p>
</form>
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

