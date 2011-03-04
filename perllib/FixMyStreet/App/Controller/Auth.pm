package FixMyStreet::App::Controller::Auth;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use Email::Valid;
use Net::Domain::TLD;
use mySociety::AuthToken;
use Digest::SHA1 qw(sha1_hex);

=head1 NAME

FixMyStreet::App::Controller::Auth - Catalyst Controller

=head1 DESCRIPTION

Controller for all the authentication related pages - create account, login,
logout.

=head1 METHODS

=head2 index

Present the user with a login / create account page. 

=cut

sub general : Path : Args(0) {
    my ( $self, $c ) = @_;
    my $req = $c->req;

    # all done unless we have a form posted to us
    return unless $req->method eq 'POST';

    # decide which action to take
    $c->detach('email_login') if $req->param('email_login');
    $c->detach('login');    # default

}

=head2 login

Allow the user to legin with a username and a password.

=cut

sub login : Private {
    my ( $self, $c ) = @_;

    my $email    = $c->req->param('email')    || '';
    my $password = $c->req->param('password') || '';

    # logout just in case
    $c->logout();

    if (   $email
        && $password
        && $c->authenticate( { email => $email, password => $password } ) )
    {
        $c->res->redirect( $c->uri_for('/my') );
        return;
    }

    # could not authenticate - show an error
    $c->stash->{login_error} = 1;
}

=head2 email_login

Email the user the details they need to log in. Don't check for an account - if
there isn't one we can create it when they come back with a token (which
contains the email addresss).

=cut

sub email_login : Private {
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
            scope => 'email_login',
            data  => { email => $good_email }
        }
      );

    # log the user in, send them an email and redirect to the welcome page
    $c->stash->{token} = $token_obj->token;
    $c->send_email( 'login', { to => $good_email } );
    $c->res->redirect( $c->uri_for('token') );
}

=head2 token

Handle the 'email_login' tokens. Find the account for the email address
(creating if needed), authenticate the user and delete the token.

=cut

sub token : Local {
    my ( $self, $c, $url_token ) = @_;

    # check for a token - if none found then return
    return unless $url_token;

    # retrieve the token or return
    my $token_obj =
      $c->model('DB::Token')
      ->find( { scope => 'email_login', token => $url_token, } );

    if ( !$token_obj ) {
        $c->stash->{token_not_found} = 1;
        return;
    }

    # logout in case we are another user
    $c->logout();

    # get the email and scrap the token
    my $email = $token_obj->data->{email};
    $token_obj->delete;

    # find or create the user related to the token and delete the token
    my $user = $c->model('DB::User')->find_or_create( { email => $email } );
    $c->authenticate( { email => $user->email }, 'no_password' );

    # send the user to their page
    $c->res->redirect( $c->uri_for('/my') );
}

=head2 change_password

Let the user change their password.

=cut

sub change_password : Local {
    my ( $self, $c ) = @_;

    # FIXME - should be logged in
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
    $c->user->obj->update( { password => sha1_hex($new) } );
    $c->stash->{password_changed} = 1;

}

=head2 logout

Log the user out. Tell them we've done so.

=cut

sub logout : Local {
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
