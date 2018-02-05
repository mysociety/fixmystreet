package Catalyst::Plugin::FixMyStreet::Session::StoreSessions;
use Moose::Role;
use namespace::autoclean;

after set_authenticated => sub {
    my $c = shift;
    my $sessions = $c->user->get_extra_metadata('sessions');
    push @$sessions, $c->sessionid;
    $c->user->set_extra_metadata('sessions', $sessions);
    $c->user->update;
};

before logout => sub {
    my $c = shift;
    if (my $user = $c->user) {
        my $sessions = $user->get_extra_metadata('sessions');
        $sessions = [ grep { $_ ne $c->sessionid } @$sessions ];
        @$sessions ? $user->set_extra_metadata('sessions', $sessions) : $user->unset_extra_metadata('sessions');
        $user->update;
    }
};

__PACKAGE__;
