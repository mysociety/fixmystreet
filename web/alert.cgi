#!/usr/bin/perl -w

# alert.cgi:
# Alert code for Neighbourhood Fix-It
#
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: alert.cgi,v 1.1 2007-01-26 01:01:23 matthew Exp $

use strict;
require 5.8.0;

# Horrible boilerplate to set up appropriate library paths.
use FindBin;
use lib "$FindBin::Bin/../perllib";
use lib "$FindBin::Bin/../../perllib";

use Page;
use mySociety::Alert;
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
    if (my $token = $q->param('token')) {
        my $data = mySociety::AuthToken::retrieve('alert', $token);
	if (my $id = $data->{id}) {
	    my $type = $data->{type};
            if ($type eq 'subscribe') {
                mySociety::Alert::confirm($id);
                $out = '<p>You have successfully confirmed your alert.</p>';
            } elsif ($type eq 'unsubscribe') {
                mySociety::Alert::delete($id);
                $out = '<p>You have successfully deleted your alert.</p>';
            }
        } else {
            $out = <<EOF;
<p>Thank you for trying to confirm your update or problem. We seem to have a
problem ourselves though, so <a href="/contact">please let us know what went on</a>
and we'll look into it.
EOF
        }
    } elsif (my $email = $q->param('email')) {
        # XXX: Need to validate email
        my $type = $q->param('type');
	my $alert_id;
        if ($type eq 'updates') {
	    my $id = $q->param('id');
	    $alert_id = mySociety::Alert::create($email, 'new_updates', $id);
	} elsif ($type eq 'problems') {
	    $alert_id = mySociety::Alert::create($email, 'new_problems');
	} else {
	    throw mySociety::Alert::Error('Invalid type');
	}
        my %h = ();
        $h{url} = mySociety::Config::get('BASE_URL') . '/A/'
	    . mySociety::AuthToken::store('alert', { id => $alert_id, type => 'subscribe' } );
        dbh()->commit();
	$out = Page::send_email($email, undef, 'alert-confirm', %h);
    } else {
	$out = 'This should probably show some sort of subscribe page.';
    }

    print Page::header($q, 'Confirmation');
    print $out;
    print Page::footer();
}
Page::do_fastcgi(\&main);

