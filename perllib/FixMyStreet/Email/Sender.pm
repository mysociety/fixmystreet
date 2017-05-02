package FixMyStreet::Email::Sender;

use parent Email::Sender::Simple;
use strict;
use warnings;

use Email::Sender::Util;
use FixMyStreet;

=head1 NAME

FixMyStreet::Email::Sender

=head1 DESCRIPTION

Subclass of Email::Sender - configuring it correctly according to our config.

If the config value 'SMTP_SMARTHOST' is set then email is routed via SMTP to
that. Otherwise it is sent using a 'sendmail' like binary on the local system.

And finally if if FixMyStreet->test_mode returns true then emails are not sent
at all but are stored in memory for the test suite to inspect (using
Email::Send::Test).

=cut

sub build_default_transport {
    if ( FixMyStreet->test_mode ) {
        Email::Sender::Util->easy_transport(Test => {});
    } elsif ( my $smtp_host = FixMyStreet->config('SMTP_SMARTHOST') ) {
        my $type = FixMyStreet->config('SMTP_TYPE') || '';
        my $port = FixMyStreet->config('SMTP_PORT') || '';
        my $username = FixMyStreet->config('SMTP_USERNAME') || '';
        my $password = FixMyStreet->config('SMTP_PASSWORD') || '';

        my $ssl = $type eq 'tls' ? 'starttls' : $type eq 'ssl' ? 'ssl' : '';
        my $args = {
            host => $smtp_host,
            ssl => $ssl,
            sasl_username => $username,
            sasl_password => $password,
        };
        $args->{port} = $port if $port;
        Email::Sender::Util->easy_transport(SMTP => $args);
    } else {
        Email::Sender::Util->easy_transport(Sendmail => {});
    }
}

1;
