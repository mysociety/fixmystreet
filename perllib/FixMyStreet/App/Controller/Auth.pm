package FixMyStreet::App::Controller::Auth;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use Email::Valid;
use Net::Domain::TLD;
use mySociety::AuthToken;

=head1 NAME

FixMyStreet::App::Controller::Auth - Catalyst Controller

=head1 DESCRIPTION

Controller for all the authentication related pages - create account, sign in,
sign out.

=head1 METHODS

=head2 index

Present the user with a sign in / create account page.

=cut

sub general : Path : Args(0) {
    my ( $self, $c ) = @_;
    my $req = $c->req;

    $c->detach( 'redirect_on_signin', [ $req->param('r') ] )
        if $c->user && $req->param('r');

    # all done unless we have a form posted to us
    return unless $req->method eq 'POST';

    # decide which action to take
    $c->detach('email_sign_in') if $req->param('email_sign_in');

       $c->forward( 'sign_in' )
    && $c->detach( 'redirect_on_signin', [ $req->param('r') ] );

}

=head2 sign_in

Allow the user to sign in with a username and a password.

=cut

sub sign_in : Private {
    my ( $self, $c, $email ) = @_;

    $email        ||= $c->req->param('email')            || '';
    my $password    = $c->req->param('password_sign_in') || '';
    my $remember_me = $c->req->param('remember_me')      || 0;

    # Sign out just in case
    $c->logout();

    if (   $email
        && $password
        && $c->authenticate( { email => $email, password => $password } ) )
    {

        # unless user asked to be remembered limit the session to browser
        $c->set_session_cookie_expire(0)
          unless $remember_me;

        return 1;
    }

    $c->stash(
        sign_in_error => 1,
        email => $email,
        remember_me => $remember_me,
    );
    return;
}

=head2 email_sign_in

Email the user the details they need to sign in. Don't check for an account - if
there isn't one we can create it when they come back with a token (which
contains the email addresss).

=cut

sub email_sign_in : Private {
    my ( $self, $c ) = @_;

    # check that the email is valid - otherwise flag an error
    my $raw_email = lc( $c->req->param('email') || '' );

    my $email_checker = Email::Valid->new(
        -mxcheck  => 1,
        -tldcheck => 1,
        -fqdn     => 1,
    );

    my $good_email = $email_checker->address($raw_email);
    if ( !$good_email ) {
        $c->stash->{email} = $raw_email;
        $c->stash->{email_error} =
          $raw_email ? $email_checker->details : 'missing';
        return;
    }

    my $token_obj = $c->model('DB::Token')    #
      ->create(
        {
            scope => 'email_sign_in',
            data  => {
                email => $good_email,
                r => $c->req->param('r'),
                name => $c->req->param('name'),
                password => $c->req->param('password_register'),
            }
        }
      );

    $c->stash->{token} = $token_obj->token;
    $c->send_email( 'login.txt', { to => $good_email } );
    $c->stash->{template} = 'auth/token.html';
}

=head2 token

Handle the 'email_sign_in' tokens. Find the account for the email address
(creating if needed), authenticate the user and delete the token.

=cut

sub token : Path('/M') : Args(1) {
    my ( $self, $c, $url_token ) = @_;

    # retrieve the token or return
    my $token_obj = $url_token
      ? $c->model('DB::Token')->find( {
          scope => 'email_sign_in', token => $url_token
        } )
      : undef;

    if ( !$token_obj ) {
        $c->stash->{token_not_found} = 1;
        return;
    }

    # Sign out in case we are another user
    $c->logout();

    # get the email and scrap the token
    my $data = $token_obj->data;
    $token_obj->delete;

    # find or create the user related to the token.
    my $user = $c->model('DB::User')->find_or_create( { email => $data->{email} } );
    $user->name( $data->{name} ) if $data->{name};
    $user->password( $data->{password} ) if $data->{password};
    $user->update;

    $c->authenticate( { email => $user->email }, 'no_password' );

    # send the user to their page
    $c->detach( 'redirect_on_signin', [ $data->{r} ] );
}

=head2 redirect_on_signin

Used after signing in to take the person back to where they were.

=cut


sub redirect_on_signin : Private {
    my ( $self, $c, $redirect ) = @_;
    $redirect = 'my' unless $redirect;
    $c->res->redirect( $c->uri_for( "/$redirect" ) );
}

=head2 redirect

Used when trying to view a page that requires sign in when you're not.

=cut

sub redirect : Private {
    my ( $self, $c ) = @_;

    my $uri = $c->uri_for( '/auth', { r => $c->req->path } );
    $c->res->redirect( $uri );
    $c->detach;

}

=head2 change_password

Let the user change their password.

=cut

sub change_password : Local {
    my ( $self, $c ) = @_;

    $c->detach( 'redirect' ) unless $c->user;

    # FIXME - CSRF check here
    # FIXME - minimum criteria for passwords (length, contain number, etc)

    # If not a post then no submission
    return unless $c->req->method eq 'POST';

    # get the passwords
    my $new     = $c->req->param('new_password') // '';
    my $confirm = $c->req->param('confirm')      // '';

    # check for errors
    my $password_error =
       !$new && !$confirm ? 'missing'
      : $new ne $confirm ? 'mismatch'
      :                    '';

    if ($password_error) {
        $c->stash->{password_error} = $password_error;
        $c->stash->{new_password}   = $new;
        $c->stash->{confirm}        = $confirm;
        return;
    }

    # we should have a usable password - save it to the user
    $c->user->obj->update( { password => $new } );
    $c->stash->{password_changed} = 1;

}

=head2 sign_out

Log the user out. Tell them we've done so.

=cut

sub sign_out : Local {
    my ( $self, $c ) = @_;
    $c->logout();
}

=head2 check_auth

Utility page - returns a simple message 'OK' and a 200 response if the user is
authenticated and a 'Unauthorized' / 401 reponse if they are not.

Mainly intended for testing but might also be useful for ajax calls.

=cut

sub check_auth : Local {
    my ( $self, $c ) = @_;

    # choose the response
    my ( $body, $code )    #
      = $c->user
      ? ( 'OK', 200 )
      : ( 'Unauthorized', 401 );

    # set the response
    $c->res->body($body);
    $c->res->code($code);

    # NOTE - really a 401 response should also contain a 'WWW-Authenticate'
    # header but we ignore that here. The spec is not keeping up with usage.

    return;
}

__PACKAGE__->meta->make_immutable;

1;
