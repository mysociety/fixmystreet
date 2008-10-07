#!/usr/bin/perl -w -I../perllib

# tms-signup.cgi
# Showing interest in TextMyStreet
#
# Copyright (c) 2008 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org. WWW: http://www.mysociety.org
#
# $Id: tms-signup.cgi,v 1.3 2008-10-07 16:27:35 matthew Exp $

use strict;
use Standard;
use Digest::SHA1 qw(sha1_hex);
use CrossSell;
use mySociety::Alert;
use mySociety::AuthToken;
use mySociety::Config;
use mySociety::EmailUtil qw(is_valid_email);
use mySociety::PostcodeUtil qw(is_valid_postcode);
use mySociety::Web qw(ent);

    #dbh()->'insert into textmystreet (name, email, postcode, mobile) values ()';

sub main {
    my $q = shift;
    my $out = '';
    my $title = 'Confirmation';
    if (my $token = $q->param('token')) {
        my $data = mySociety::AuthToken::retrieve('tms', $token);
        if ($data->{email}) {
            $out = tms_token($q, $data);
        } else {
            $out = $q->p(<<EOF);
Thank you for trying to confirm your interest. We seem to have a problem ourselves
though, so <a href="/contact">please let us know what went on</a> and we'll look into it.
EOF
        }
    } elsif ($q->param('email')) {
        $out = tms_do_subscribe($q);
    } else {
        $out = tms_updates_form($q);
    }

    print Page::header($q, title => $title);
    print $out;
    print Page::footer($q);
}
Page::do_fastcgi(\&main);

sub tms_updates_form {
    my ($q, @errors) = @_;
    my @vars = qw(email name postcode mobile signed_email);
    my %input = map { $_ => $q->param($_) || '' } @vars;
    my $out = '';
    if (@errors) {
        $out .= '<ul id="error"><li>' . join('</li><li>', @errors) . '</li></ul>';
    }
    $out .= CrossSell::display_tms_form(%input);
    return $out;
}

sub tms_token {
    my ($q, $data) = @_;
    my $type = $data->{type};
    my $out = '';
    if ($type eq 'subscribe') {
        tms_confirm(%$data);
        $out = $q->p('You have successfully registered your interest.');
        $out .= CrossSell::display_advert($q, $data->{email}, $data->{name}, done_tms => 1);
    }
    return $out;
}

sub tms_do_subscribe {
    my ($q) = @_;
    my @vars = qw(email name postcode mobile signed_email);
    my %input = map { $_ => $q->param($_) || '' } @vars;

    my @errors;
    push @errors, 'Please enter your name' unless $input{name};
    push @errors, 'Please enter a valid email address' unless is_valid_email($input{email});
    push @errors, 'Please enter a valid postcode' unless is_valid_postcode($input{postcode});
    push @errors, 'Please enter a mobile number' unless $input{mobile};
    if (@errors) {
        return tms_updates_form($q, @errors);
    }

    # See if email address has been signed
    if ($input{signed_email}) {
        my $out;
        if (mySociety::AuthToken::verify_with_shared_secret($input{email}, mySociety::Config::get('AUTH_SHARED_SECRET'), $input{signed_email})) {
            tms_confirm(%input);
            $out = $q->p('You have successfully registered your interest.');
            return $out;
        }
    }

    my %h = ();
    $h{url} = mySociety::Config::get('BASE_URL') . '/T/'
        . mySociety::AuthToken::store('tms', {
            type => 'subscribe',
            name => $input{name},
            email => $input{email},
            postcode => $input{postcode},
            mobile => $input{mobile},
        });
    dbh()->commit();
    return Page::send_email($q, $input{email}, $input{name}, 'tms', %h);
}

sub tms_confirm {
    my %input = @_;
    dbh()->do("insert into textmystreet (name, email, postcode, mobile) values (?, ?, ?, ?)", {},
        $input{name}, $input{email}, $input{postcode}, $input{mobile});
    dbh()->commit();
}

