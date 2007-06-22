#!/usr/bin/perl -w

# confirm.cgi:
# Confirmation code for FixMyStreet
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: confirm.cgi,v 1.22 2007-06-22 13:39:10 matthew Exp $

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
            my ($o, $problem_id, $email, $creator_fixed) = confirm_update($q, $id);
            if ($creator_fixed) {
                $out = ask_questionnaire($token);
            } else {
                $out = $o . advertise_updates($q, $problem_id, $email);
            }
        } elsif ($type eq 'problem') {
            my ($o, $email) = confirm_problem($q, $id);
            $out = $o . advertise_updates($q, $id, $email);
        } elsif ($type eq 'questionnaire') {
            $out = add_questionnaire($q, $id, $token);
        }
        dbh()->commit();
    } else {
        $out = $q->p(_(<<EOF));
Thank you for trying to confirm your update or problem. We seem to have a
problem ourselves though, so <a href="/contact">please let us know what went on</a>
and we'll look into it.
EOF
    }

    print Page::header($q, title=>_('Confirmation'));
    print $out;
    print Page::footer();
    dbh()->rollback();
}
Page::do_fastcgi(\&main);

sub confirm_update {
    my ($q, $id) = @_;
    dbh()->do("update comment set state='confirmed' where id=? and state='unconfirmed'", {}, $id);
    my ($problem_id, $fixed, $email) = dbh()->selectrow_array(
        "select problem_id, mark_fixed, email from comment where id=?", {}, $id);
    my $creator_fixed;
    if ($fixed) {
        dbh()->do("update problem set state='fixed', lastupdate = ms_current_timestamp()
            where id=? and state='confirmed'", {}, $problem_id);
        # If a problem reporter is marking their own problem as fixed, turn off questionnaire sending
        $creator_fixed = dbh()->do("update problem set send_questionnaire='f' where id=? and email=?", {}, $problem_id, $email);
    } else { 
        # Only want to refresh problem if not already fixed
        dbh()->do("update problem set lastupdate = ms_current_timestamp()
            where id=? and state='confirmed'", {}, $problem_id);
    }
    my $out = '';
    if (!$creator_fixed) {
        $out .= '<form action="/alert" method="post">';
        $out .= $q->p(sprintf(_('You have successfully confirmed your update and you can now <a href="%s">view it on the site</a>.'), "/?id=$problem_id#update_$id"));
    }
    return ($out, $problem_id, $email, $creator_fixed);
}

sub confirm_problem {
    my ($q, $id) = @_;
    dbh()->do("update problem set state='confirmed', confirmed=ms_current_timestamp(), lastupdate=ms_current_timestamp()
        where id=? and state='unconfirmed'", {}, $id);
    my ($council, $email) = dbh()->selectrow_array("select council, email from problem where id=?", {}, $id);
    my $out = '<form action="/alert" method="post">';
    $out .= $q->p(
        _('You have successfully confirmed your problem')
        . ($council ? _(' and <strong>we will now send it to the council</strong>') : '')
        . sprintf(_('. You can <a href="%s">view the problem on this site</a>.'), "/?id=$id")
    );
    return ($out, $email);
}

sub advertise_updates {
    my ($q, $problem_id, $email) = @_;
    my $salt = unpack('h*', random_bytes(8));
    my $secret = scalar(dbh()->selectrow_array('select secret from secret'));
    my $signed_email = sha1_hex("$problem_id-$email-$salt-$secret");
    my $signup = <<EOF;
<input type="hidden" name="signed_email" value="$salt,$signed_email">
<input type="hidden" name="email" value="$email">
<input type="hidden" name="id" value="$problem_id">
<input type="hidden" name="type" value="updates">
EOF
    $signup .= '<input type="submit" value="' . _('sign up') . '">';
    my $out = $q->p(sprintf(_('You could also <a href="%s">subscribe to the RSS feed</a> of updates by other local people on this problem, or %s if you wish to receive updates by email.'), "/rss/$problem_id", $signup));
    $out .= '</form>';
    return $out;
}

sub ask_questionnaire {
    my ($token) = @_;
    my $out = <<EOF;
<form action="/confirm" method="post">
<input type="hidden" name="type" value="questionnaire">
<input type="hidden" name="token" value="$token">
<p>Thanks, glad to hear it's been fixed! Could we just ask if you have ever reported a problem to a council before?</p>
<p align="center">
<input type="radio" name="reported" id="reported_yes" value="Yes">
<label for="reported_yes">Yes</label>
<input type="radio" name="reported" id="reported_no" value="No">
<label for="reported_no">No</label>
<input type="submit" value="Go">
</p>
</form>
EOF
    return $out;
}

sub add_questionnarie {
    my ($q, $id, $token) = @_;
    my $problem_id = dbh()->selectrow_array("select problem_id from comment where id=?", {}, $id);
    my $reported = $q->param('reported');
    $reported = $reported eq 'Yes' ? 't' : ($reported eq 'No' ? 'f' : undef);
    return ask_questionnaire($token) unless $reported;
    dbh()->do("insert into questionnaire (problem_id, whensent, whenanswered,
        ever_reported, old_state, new_state) values (?, ms_current_timestamp(),
        ms_current_timestamp(), ?, 'confirmed', 'fixed');", {}, $problem_id, $reported);
    my $out = $q->p(sprintf('Thank you - <a href="%s">view your problem</a>.', "/?id=$problem_id"));
    return $out;
}

