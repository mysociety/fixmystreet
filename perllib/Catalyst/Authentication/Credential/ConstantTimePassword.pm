package Catalyst::Authentication::Credential::ConstantTimePassword;
use Moose;
extends 'Catalyst::Authentication::Credential::Password';

# Override of parent function to check password even if user does not exist
sub authenticate {
    my ( $self, $c, $realm, $authinfo ) = @_;

    ## because passwords may be in a hashed format, we have to make sure that we remove the
    ## password_field before we pass it to the user routine, as some auth modules use
    ## all data passed to them to find a matching user...
    my $userfindauthinfo = {%{$authinfo}};
    delete($userfindauthinfo->{$self->_config->{'password_field'}});

    # Assuming store is DBIx::Class DB::User, which it is here. Must be
    # done on all requests. Does an encode, so slows this down further.
    my $empty = $c->model("DB::User")->new({ password => '' });

    my $user_obj = $realm->find_user($userfindauthinfo, $c);
    if (ref($user_obj)) {
        if ($self->check_password($user_obj, $authinfo)) {
            return $user_obj;
        }
    } else {
        # Still perform a check to remain constant time
        $self->check_password($empty, $authinfo);
        $c->log->debug(
            'Unable to locate user matching user info provided in realm: '
            . $realm->name
            ) if $c->debug;
        return;
    }
}

__PACKAGE__;

__END__

=pod

=head1 NAME

Catalyst::Authentication::Credential::ConstantTimePassword - same
as ::Password but constant time in the check credential configuration.

=cut
