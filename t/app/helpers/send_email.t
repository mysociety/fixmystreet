#!/usr/bin/perl

use strict;
use warnings;
use utf8;

BEGIN {
    use FixMyStreet;
    FixMyStreet->test_mode(1);
}

use Test::More tests => 5;

use Email::Send::Test;
use Path::Class;

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

# Get the email, check it has a date and then strip it out
my $email_as_string = $emails[0]->as_string;
ok $email_as_string =~ s{\s+Date:\s+\S.*?$}{}xms, "Found and stripped out date";


is $email_as_string,
  file(__FILE__)->dir->file('send_email_sample.txt')->slurp,
  "email is as expected";
