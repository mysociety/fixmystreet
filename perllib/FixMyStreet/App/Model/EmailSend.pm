package FixMyStreet::App::Model::EmailSend;
use base 'Catalyst::Model::Adaptor';

use strict;
use warnings;

use FixMyStreet;
use Email::Send;

=head1 NAME

FixMyStreet::App::Model::EmailSend

=head1 DESCRIPTION

Thin wrapper around Email::Send - configuring it correctly acording to our config.

If the config value 'SMTP_SMARTHOST' is set then email is routed via SMTP to
that. Otherwise it is sent using a 'sendmail' like binary on the local system.

And finally if if FixMyStreet->test_mode returns true then emails are not sent
at all but are stored in memory for the test suite to inspect (using
Email::Send::Test).

=cut

my $args = undef;

if ( FixMyStreet->test_mode ) {

    # Email::Send::Test
    $args = { mailer => 'Test', };
}
elsif ( my $smtp_host = FixMyStreet->config('SMTP_SMARTHOST') ) {

    # Email::Send::SMTP
    $args = {
        mailer      => 'FixMyStreet::EmailSend',
        mailer_args => [ Host => $smtp_host ],
    };
}
else {

    # Email::Send::Sendmail
    $args = { mailer => 'Sendmail' };
}

__PACKAGE__->config(
    class => 'Email::Send',
    args  => $args,
);
