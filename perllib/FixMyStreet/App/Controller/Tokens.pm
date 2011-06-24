package FixMyStreet::App::Controller::Tokens;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::Tokens - Handle auth tokens

=head1 DESCRIPTION

Act on the various tokens that can be submitted.

=head1 METHODS

=cut

=head2 confirm_problem

    /P/([0-9A-Za-z]{16,18}).*$

Confirm a problem - url appears in emails sent to users after they create the
problem but are not logged in.

=cut

sub confirm_problem : Path('/P') {
    my ( $self, $c, $token_code ) = @_;

    my $auth_token =
      $c->forward( 'load_auth_token', [ $token_code, 'problem' ] );

    # Load the problem
    my $problem_id = $auth_token->data->{id};
    my $problem = $c->cobrand->problems->find( { id => $problem_id } )
      || $c->detach('token_error');
    $c->stash->{problem} = $problem;

    # check that this email or domain are not the cause of abuse. If so hide it.
    if ( $problem->is_from_abuser ) {
        $problem->update(
            { state => 'hidden', lastupdate => \'ms_current_timestamp()' } );
        $c->stash->{template} = 'tokens/abuse.html';
        return;
    }

    # We have a problem - confirm it if needed!
    $problem->update(
        {
            state      => 'confirmed',
            confirmed  => \'ms_current_timestamp()',
            lastupdate => \'ms_current_timestamp()',
        }
    ) if $problem->state eq 'unconfirmed';

    # Subscribe problem reporter to email updates
    $c->stash->{report} = $c->stash->{problem};
    $c->forward( '/report/new/create_reporter_alert' );

    # log the problem creation user in to the site
    $c->authenticate( { email => $problem->user->email }, 'no_password' );
    $c->set_session_cookie_expire(0);

    return 1;
}

=head2 redirect_to_partial_problem

    /P/...

Redirect user to continue filling in a partial problem. The request is sent to
'/report/new' which might redirect again to '/around' if there is no location
found.

=cut

sub redirect_to_partial_problem : Path('/L') {
    my ( $self, $c, $token_code ) = @_;

    my $url = $c->uri_for( "/report/new", { partial => $token_code } );
    return $c->res->redirect($url);
}

=head2 confirm_alert

    /A/([0-9A-Za-z]{16,18}).*$

Confirm an alert - url appears in emails sent to users after they create the
alert but are not logged in.

=cut

sub confirm_alert : Path('/A') {
    my ( $self, $c, $token_code ) = @_;

    my $auth_token = $c->forward( 'load_auth_token', [ $token_code, 'alert' ] );

    # Load the problem
    my $alert_id = $auth_token->data->{id};
    $c->stash->{confirm_type} = $auth_token->data->{type};
    my $alert = $c->model('DB::Alert')->find( { id => $alert_id } )
      || $c->detach('token_error');
    $c->stash->{alert} = $alert;

    # check that this email or domain are not the cause of abuse. If so hide it.
    if ( $alert->is_from_abuser ) {
        $c->stash->{template} = 'tokens/abuse.html';
        return;
    }

    $c->authenticate( { email => $alert->user->email }, 'no_password' );
    $c->set_session_cookie_expire(0);

    $c->forward('/alert/confirm');

    return 1;
}

=head2 confirm_update

    /C/([0-9A-Za-z]{16,18}).*$

Confirm an update - url appears in emails sent to users after they create the
update but are not logged in.

=cut

sub confirm_update : Path('/C') {
    my ( $self, $c, $token_code ) = @_;

    my $auth_token =
      $c->forward( 'load_auth_token', [ $token_code, 'comment' ] );

    # Load the problem
    my $comment_id = $auth_token->data->{id};
    $c->stash->{add_alert} = $auth_token->data->{add_alert};

    my $comment = $c->model('DB::Comment')->find( { id => $comment_id } )
      || $c->detach('token_error');
    $c->stash->{update} = $comment;

    # check that this email or domain are not the cause of abuse. If so hide it.
    if ( $comment->is_from_abuser ) {
        $c->stash->{template} = 'tokens/abuse.html';
        return;
    }

    $c->authenticate( { email => $comment->user->email }, 'no_password' );
    $c->set_session_cookie_expire(0);

    $c->forward('/report/update/confirm');

    return 1;
}

sub load_questionnaire_id : Private {
    my ( $self, $c, $token_code ) = @_;

    # Set up error handling
    $c->stash->{error_template} = 'errors/generic.html';
    $c->stash->{message} = _("I'm afraid we couldn't validate that token. If you've copied the URL from an email, please check that you copied it exactly.\n");

    my $auth_token = $c->forward( 'load_auth_token', [ $token_code, 'questionnaire' ] );
    $c->stash->{id} = $auth_token->data;
    $c->stash->{token} = $token_code;
}

sub questionnaire : Path('/Q') : Args(1) {
    my ( $self, $c, $token_code ) = @_;
    $c->forward( 'load_questionnaire_id', [ $token_code ] );
    $c->forward( '/questionnaire/index');
}

=head2 load_auth_token

    my $auth_token =
      $c->forward( 'load_auth_token', [ $token_code, $token_scope ] );


Load the token if possible. If token is not found, or not valid detach to a nice
error message.

=cut

sub load_auth_token : Private {
    my ( $self, $c, $token_code, $scope ) = @_;

    # clean the token of bad chars (in case of email client issues)
    $token_code ||= '';
    $token_code =~ s{[^a-zA-Z0-9]+}{}g;

    # try to load the token
    my $token = $c->model('DB::Token')->find(
        {
            scope => $scope,
            token => $token_code,
        }
    ) || $c->detach('token_error');

    return $token;
}

=head2 token_error

Display an error page saying that there is something wrong with the token.

=cut

sub token_error : Private {
    my ( $self, $c ) = @_;
    $c->stash->{template} = $c->stash->{error_template} || 'tokens/error.html';
    $c->detach;
}

__PACKAGE__->meta->make_immutable;

1;
