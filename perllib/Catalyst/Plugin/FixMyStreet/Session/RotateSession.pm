package Catalyst::Plugin::FixMyStreet::Session::RotateSession;
use Moose::Role;
use namespace::autoclean;

# After successful authentication, rotate the session ID
after set_authenticated => sub {
    my $c = shift;
    $c->change_session_id;
};

# The below is necessary otherwise the rotation fails due to the delegate
# holding on to the now-deleted old session. See
# https://rt.cpan.org/Public/Bug/Display.html?id=112679

after delete_session_data => sub {
    my ($c, $key) = @_;

    my ($field) = split(':', $key);
    if ($field eq 'session') {
        $c->_session_store_delegate->_session_row(undef);
    } elsif ($field eq 'flash') {
        $c->_session_store_delegate->_flash_row(undef);
    }
};

1;
