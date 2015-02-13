package FixMyStreet::EmailSend::ContactEmail;
use base Email::Send::SMTP;

sub get_env_sender {
    my $sender = FixMyStreet->config('CONTACT_EMAIL');
    return $sender;
}

1;
