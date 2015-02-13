package FixMyStreet::EmailSend::DoNotReply;
use base Email::Send::SMTP;

sub get_env_sender {
    my $sender = FixMyStreet->config('DO_NOT_REPLY_EMAIL');
    return $sender;
}

1;
