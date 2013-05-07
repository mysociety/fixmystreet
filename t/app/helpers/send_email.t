#!/usr/bin/perl

use strict;
use warnings;
use utf8;

BEGIN {
    use FixMyStreet;
    FixMyStreet->test_mode(1);
}

use Test::More tests => 5;

use Catalyst::Test 'FixMyStreet::App';

use Email::Send::Test;
use Path::Class;

my $c = ctx_request("/");

# set some values in the stash
$c->stash->{foo} = 'bar';

# clear the email queue
Email::Send::Test->clear;

# send the test email
ok $c->send_email( 'test.txt', { to => 'test@recipient.com' } ),
  "sent an email";

# check it got templated and sent correctly
my @emails = Email::Send::Test->emails;
is scalar(@emails), 1, "caught one email";

# Get the email, check it has a date and then strip it out
my $email_as_string = $emails[0]->as_string;
ok $email_as_string =~ s{\s+Date:\s+\S.*?$}{}xms, "Found and stripped out date";
ok $email_as_string =~ s{\s+Message-ID:\s+\S.*?$}{}xms, "Found and stripped out message ID (contains epoch)";

my $expected_email_content =   file(__FILE__)->dir->file('send_email_sample.txt')->slurp;
my $name = FixMyStreet->config('CONTACT_NAME');
$name = "\"$name\"" if $name =~ / /;
my $sender = $name . ' <' . FixMyStreet->config('DO_NOT_REPLY_EMAIL') . '>';
$expected_email_content =~ s{CONTACT_EMAIL}{$sender};

is $email_as_string,
$expected_email_content,
  "email is as expected";
