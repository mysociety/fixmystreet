package FixMyStreet::Script::CreateSuperuser;

use strict;
use warnings;

use FixMyStreet;
use FixMyStreet::DB;

sub createsuperuser {
    my ($email, $password) = @_;

    unless ($email) {
        warn "Specify a single email address and optionally password to create a superuser or grant superuser status to.\n";
        return 1;
    }

    my $user = FixMyStreet::DB->resultset('User')->find_or_new({ email => $email });
    if ( !$user->in_storage ) {
        unless ($password) {
            warn "Specify a password for this new user.\n";
            return 1;
        }
        $user->password($password);
        $user->is_superuser(1);
        $user->insert;
    } else {
        $user->update({ is_superuser => 1 });
    }
    print $user->email . " is now a superuser.\n";
    return 0;
}

1;
