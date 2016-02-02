package FixMyStreet::EmailSend::Variable;
use base Email::Send::SMTP;
use FixMyStreet;

my $sender;

sub send {
    my ($class, $message, %args) = @_;
    $sender = delete($args{env_from}) || FixMyStreet->config('DO_NOT_REPLY_EMAIL');
    $class->SUPER::send($message, %args);
}

sub get_env_sender {
    $sender;
}

1;
