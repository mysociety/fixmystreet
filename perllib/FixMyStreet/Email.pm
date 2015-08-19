package FixMyStreet::Email;

use Utils::Email;
use FixMyStreet;

sub test_dmarc {
    my $email = shift;
    return if FixMyStreet->test_mode;
    return Utils::Email::test_dmarc($email);
}

1;
