#!/usr/bin/perl

use strict;
use warnings;
use utf8;

BEGIN {
    use FixMyStreet;
    FixMyStreet->test_mode(1);
}

use Test::More tests => 4;

use Email::Send::Test;

use_ok 'FixMyStreet::App';
my $c = FixMyStreet::App->new;

# fake up the request a little
$c->req->uri( URI->new('http://localhost/') );
$c->req->base( $c->req->uri );


# set some values in the stash
$c->stash->{foo} = 'bar';

# clear the email queue
Email::Send::Test->clear;

# send the test email
ok $c->send_email( 'test', { to => 'test@recipient.com' } ), "sent an email";

# check it got templated and sent correctly
my @emails = Email::Send::Test->emails;
is scalar(@emails), 1, "caught one email";

is $emails[0]->as_string, << 'END_OF_BODY', "email is as expected";
Subject: test email
From: evdb@ecclestoad.co.uk
To: test@recipient.com
Content-Type: text/plain; charset="utf-8"

Hello,

This is a test email where foo: bar.

utf8: 我们应该能够无缝处理UTF8编码

Yours,
  FixMyStreet.
END_OF_BODY

