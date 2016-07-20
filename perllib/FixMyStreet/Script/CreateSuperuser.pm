package FixMyStreet::Script::CreateSuperuser;

use strict;
use warnings;

use FixMyStreet;
use FixMyStreet::DB;

sub createsuperuser {
    die "Specify a single email address and optionally password to create a superuser or grant superuser status to." if (@ARGV < 1 || @ARGV > 2);

    my $user = FixMyStreet::DB->resultset('User')->find_or_new({ email => $ARGV[0] });
    if ( !$user->in_storage ) {
        die "Specify a password for this new user." if (@ARGV < 2);
        $user->password($ARGV[1]);
        $user->is_superuser(1);
        $user->insert;
    } else {
        $user->update({ is_superuser => 1 });
    }
    print $user->email . " is now a superuser.\n";
}


1;