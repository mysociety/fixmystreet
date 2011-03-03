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

    # check that the email is valid - otherwise flag an error
    my $raw_email = $req->param('email') || '';
    my $email_checker = Email::Valid->new(
        -mxcheck  => 1,
        -tldcheck => 1,
        -fqdn     => 1,
    );

    if ( my $good_email = $email_checker->address($raw_email) ) {
        $c->stash->{email} = $good_email;
    }
    else {
        $c->stash->{email} = $raw_email;
        $c->stash->{email_error} =
          $raw_email ? $email_checker->details : 'missing';
        return;
    }

    # decide which action to take
    $c->detach('create_account') if $req->param('create_account');

    # hmm - should not get this far. 404 so that user knows there is a problem
    # rather than it silently not working.
    $c->detach('/page_not_found');

}

=head2 create_account

Create an account for the user, send them an email with confirm link and log
them in straight away. If the email address already has an account send them an
email with a password reset link (slightly leaks privacy information but
required to allow instant logins).

=cut

sub create_account : Private {
    my ( $self, $c ) = @_;
    my $email = $c->stash->{email};

    # get account from the database
    my $account = $c->model('DB::User')->find_or_new( { email => $email } );

    # Deal with existing accounts by treating it like a password reset link
    if ( $account->in_storage ) {
        $c->stash->{tried_to_create_account} = 1;
        $c->detach('email_reset');
    }

    # we have a new account
    my $password = mySociety::AuthToken::random_token();
    $account->password( sha1_hex($password) );
    $account->insert;    # save to database

    # log the user in, send them an email and redirect to the welcome page
    $c->authenticate( { email => $email, password => $password } );
    $c->send_email( 'auth_new_account_welcome', { to => $email } );
    $c->res->redirect( $c->uri_for('welcome') );
}

=head2 welcome

Page that new users are redirected to after they have created an account.

=cut

sub welcome : Local {
    my ( $self, $c ) = @_;

    # FIXME - check that user is logged in!
    # pass thru
}

=head2 confirm

Confirm that a user can receive email - url is .../confirm/$token

We don't assume that the user is logged in, but if they are they are logged out
and then logged in as the user they are confirming. The token is destroyed at
the end of the request so it cannot be reused.

=cut

sub confirm : Local {
    my ( $self, $c, $url_token ) = @_;

    # Use the token to confirm the user and return them.
    my $user = $c->model('DB::User')->confirm_user_from_token($url_token);

    # If we did not get a user back then the token was not valid
    return if !$user;

    # got a user back which is now confirmed - auth as them
    $c->logout();
    $c->authenticate( { email => $user->email }, 'no_password' );
    $c->stash->{user_now_confirmed} = 1;

    # TODO - should we redirect somewhere - perhaps to pending problems?
    return;
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
