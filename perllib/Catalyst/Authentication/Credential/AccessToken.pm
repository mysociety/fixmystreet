package Catalyst::Authentication::Credential::AccessToken;

use strict;
use warnings;
use base 'Class::Accessor::Fast';

__PACKAGE__->mk_accessors(qw(token_field));

our $VERSION = "0.01";

sub new {
    my ($class, $config, $c, $realm) = @_;
    my $self = { %$config };
    bless $self, $class;
    return $self;
}

sub get_token {
    my ($self, $c) = @_;
    my $auth_header = $c->req->header('Authorization') || '';
    my ($token) = $auth_header =~ /^Bearer (.*)/i;
    $token ||= $c->get_param('access_token');
    return $token;
}

sub authenticate {
    my ( $self, $c, $realm, $authinfo_ignored ) = @_;

    my $token = $self->get_token($c);
    return unless $token;

    my $id;
    ($id, $token) = split /-/, $token, 2;
    return unless $id =~ /^[1-9]\d*$/;

    my $user_obj = $realm->find_user({ id => $id }, $c);
    if (ref($user_obj) && $self->check_token($user_obj, $token)) {
        return $user_obj;
    }
    return;
}

sub check_token {
    my ($self, $user, $token) = @_;

    my $field = $self->token_field || 'access_token';
    my $value = $user->$field;
    return $user->_column_encoders->{password}->($token, $value) eq $value;
}

__PACKAGE__;

__END__

=pod

=head1 NAME

Catalyst::Authentication::Credential::AccessToken - Authenticate a user
with an access token.

=head1 SYNOPSIS

    use Catalyst qw/
      Authentication
      /;

    package MyApp::Controller::Auth;

    sub login : Local {
        my ( $self, $c ) = @_;
        $c->authenticate(undef, "access_token");
    }

=head1 DESCRIPTION

This authentication credential checker takes authentication information
(most often a username) and a password, and attempts to validate the password
provided against the user retrieved from the store.

=head1 CONFIGURATION

    # example
    __PACKAGE__->config('Plugin::Authentication' =>
                {
                    default_realm => 'members',
                    realms => {
                        access_token => {
                            credential => {
                                class => 'AccessToken',
                                token_field => 'access_token',
                            },
                            ...


=over 4

=item class

The classname used for Credential. This is part of
L<Catalyst::Plugin::Authentication> and is the method by which
Catalyst::Authentication::Credential::AccessToken is loaded as the
credential validator. For this module to be used, this must be set to
'AccessToken'.

=item token_field

The field in the user object that contains the access token. This will vary
depending on the storage class used, but is most likely something like
'access_token'. In fact, this is so common that if this is left out of the
config, it defaults to 'access_token'.

=back

=head1 USAGE

The AccessToken credential module is very simple to use. Once configured as
indicated above, authenticating using this module is simply a matter of calling
$c->authenticate().

    if ($c->authenticate(undef, "access_token")) {
        # authentication successful
    } else {
        # authentication failed
    }

=head1 METHODS

There are no publicly exported routines in the AccessToken module (or indeed in
most credential modules.)  However, below is a description of the routines
required by L<Catalyst::Plugin::Authentication> for all credential modules.

=head2 new( $config, $app, $realm )

Instantiate a new AccessToken object using the configuration hash provided in
$config. A reference to the application is provided as the second argument.
Note to credential module authors: new() is called during the application's
plugin setup phase, which is before the application specific controllers are
loaded. The practical upshot of this is that things like $c->model(...) will
not function as expected.

=head2 authenticate

Tries to log a user in.

=cut
