package FixMyStreet::EmailSend;
use base Email::Send::SMTP;

sub get_env_sender {
    # Should really use cobrand's contact_email function, but not sure how
    # best to access that from in here.
    my $sender = FixMyStreet->config('CONTACT_EMAIL');
    $sender =~ s/team/fms-DO-NOT-REPLY/;
    return $sender;
}

1;
