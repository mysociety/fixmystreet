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

    if ($token_code eq '_test_') {
        $c->stash->{report} = {
            id => 123,
            title => 'Title of Report',
            bodies_str => 'True',
            url => '/report/123',
        };
        return;
    }

    my $auth_token =
      $c->forward( 'load_auth_token', [ $token_code, 'problem' ] );

    # Load the problem
    my $data = $auth_token->data;
    $data = { id => $data } unless ref $data;

    my $problem_id = $data->{id};
    # Look at all problems, not just cobrand, in case am approving something we don't actually show
    my $problem = $c->model('DB::Problem')->find( { id => $problem_id } )
      || $c->detach('token_error');
    $c->stash->{report} = $problem;

    $c->detach('token_too_old')
        if $problem->state eq 'unconfirmed'
        && $auth_token->created < DateTime->now->subtract( months => 1 );

    # check that this email or domain are not the cause of abuse. If so hide it.
    if ( $problem->is_from_abuser ) {
        $problem->update(
            { state => 'hidden', lastupdate => \'ms_current_timestamp()' } );
        $c->stash->{template} = 'tokens/abuse.html';
        return;
    }

    # For Zurich, email confirmation simply sets a flag, it does not change the
    # problem state, log in, or anything else
    if ($c->cobrand->moniker eq 'zurich') {
        $problem->set_extra_metadata( email_confirmed => 1 );
        $problem->update( {
            confirmed => \'ms_current_timestamp()',
        } );

        if ( $data->{name} || $data->{password} ) {
            $problem->user->name( $data->{name} ) if $data->{name};
            $problem->user->phone( $data->{phone} ) if $data->{phone};
            $problem->user->update;
        }

        return 1;
    }

    if ($problem->state ne 'unconfirmed') {
        my $report_uri = $c->cobrand->base_url_for_report( $problem ) . $problem->url;
        $c->res->redirect($report_uri);
        return;
    }

    # We have an unconfirmed problem
    $problem->update(
        {
            state      => 'confirmed',
            confirmed  => \'ms_current_timestamp()',
            lastupdate => \'ms_current_timestamp()',
        }
    );

    # Subscribe problem reporter to email updates
    $c->forward( '/report/new/create_reporter_alert' );

    # log the problem creation user in to the site
    if ( $data->{name} || $data->{password} ) {
        $problem->user->name( $data->{name} ) if $data->{name};
        $problem->user->phone( $data->{phone} ) if $data->{phone};
        $problem->user->password( $data->{password}, 1 ) if $data->{password};
        $problem->user->title( $data->{title} ) if $data->{title};
        $problem->user->update;
    }
    $c->authenticate( { email => $problem->user->email }, 'no_password' );
    $c->set_session_cookie_expire(0);

    $c->stash->{created_report} = 'fromemail';
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

    if ($token_code eq '_test_') {
        $c->stash->{confirm_type} = $c->get_param('confirm_type');
        return;
    }

    my $auth_token = $c->forward( 'load_auth_token', [ $token_code, 'alert' ] );

    # Load the alert
    my $alert_id = $auth_token->data->{id};
    $c->stash->{confirm_type} = $auth_token->data->{type};
    my $alert = $c->model('DB::Alert')->find( { id => $alert_id } )
      || $c->detach('token_error');
    $c->stash->{alert} = $alert;

    $c->detach('token_too_old')
        if $c->stash->{confirm_type} ne 'unsubscribe'
        && $auth_token->created < DateTime->now->subtract( months => 1 );

    # check that this email or domain are not the cause of abuse. If so hide it.
    if ( $alert->is_from_abuser ) {
        $c->stash->{template} = 'tokens/abuse.html';
        return;
    }

    if (!$alert->confirmed && $c->stash->{confirm_type} ne 'unsubscribe') {
        $c->authenticate( { email => $alert->user->email }, 'no_password' );
        $c->set_session_cookie_expire(0);
    }

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

    if ($token_code eq '_test_') {
        $c->stash->{problem} = {
            id => 123,
            title => 'Title of Report',
            bodies_str => 'True',
            url => '/report/123',
        };
        return;
    }

    my $auth_token =
      $c->forward( 'load_auth_token', [ $token_code, 'comment' ] );

    # Load the update
    my $data = $auth_token->data;
    my $comment_id = $data->{id};
    $c->stash->{add_alert} = $data->{add_alert};

    my $comment = $c->model('DB::Comment')->find( { id => $comment_id } )
      || $c->detach('token_error');
    $c->stash->{update} = $comment;

    $c->detach('token_too_old')
        if $comment->state ne 'confirmed'
        && $auth_token->created < DateTime->now->subtract( months => 1 );

    # check that this email or domain are not the cause of abuse. If so hide it.
    if ( $comment->is_from_abuser ) {
        $c->stash->{template} = 'tokens/abuse.html';
        return;
    }

    if ( $comment->state ne 'unconfirmed' ) {
        my $report_uri = $c->cobrand->base_url_for_report( $comment->problem ) . $comment->problem->url;
        $c->res->redirect($report_uri);
        return;
    }

    if ( $data->{name} || $data->{password} ) {
        $comment->user->name( $data->{name} ) if $data->{name};
        $comment->user->password( $data->{password}, 1 ) if $data->{password};
        $comment->user->update;
    }

    $c->authenticate( { email => $comment->user->email }, 'no_password' );
    $c->set_session_cookie_expire(0);

    $c->forward('/report/update/confirm');

    return 1;
}

sub load_questionnaire : Private {
    my ( $self, $c, $token_code ) = @_;

    my $auth_token = $c->forward( 'load_auth_token', [ $token_code, 'questionnaire' ] );
    $c->stash->{id} = $auth_token->data;
    $c->stash->{token} = $token_code;
    $c->stash->{token_obj} = $auth_token;

    my $questionnaire = $c->model('DB::Questionnaire')->find(
        { id => $c->stash->{id} },
        { prefetch => 'problem' }
    );
    $c->detach('/questionnaire/missing_problem') unless $questionnaire;
    $c->stash->{questionnaire} = $questionnaire;
}

sub questionnaire : Path('/Q') : Args(1) {
    my ( $self, $c, $token_code ) = @_;
    $c->forward( 'load_questionnaire', [ $token_code ] );

    $c->detach('token_too_old') if $c->stash->{token_obj}->created < DateTime->now->subtract( months => 1 );

    my $questionnaire = $c->stash->{questionnaire};
    if (!$questionnaire->whenanswered) {
        $c->authenticate( { email => $questionnaire->problem->user->email }, 'no_password' );
        $c->set_session_cookie_expire(0);
    }
    $c->forward( '/questionnaire/show' );
}

=head2 alert_to_reporter

    /R/([0-9A-Za-z]{16,18}).*$

A link in an update alert to a problem reporter - show the "reopen report"
tickbox but don't log the person in.

=cut

sub alert_to_reporter : Path('/R') {
    my ( $self, $c, $token_code ) = @_;

    my $auth_token =
      $c->forward( 'load_auth_token', [ $token_code, 'alert_to_reporter' ] );
    my $data = $auth_token->data;

    my $problem_id = $data->{id};
    my $problem = $c->model('DB::Problem')->find( { id => $problem_id } )
      || $c->detach('token_error');

    $c->detach('token_too_old') if $auth_token->created < DateTime->now->subtract( months => 1 );

    $c->flash->{alert_to_reporter} = 1;
    my $report_uri = $c->cobrand->base_url_for_report( $problem ) . $problem->url;
    $c->res->redirect($report_uri);
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
    );

    unless ( $token ) {
        $c->stash->{template} = 'errors/generic.html';
        $c->stash->{message} = _("I'm afraid we couldn't validate that token. If you've copied the URL from an email, please check that you copied it exactly.\n");
        $c->detach;
    }

    return $token;
}

=head2 token_error

Display an error page saying that there is something wrong with the token (our end).

=cut

sub token_error : Private {
    my ( $self, $c ) = @_;
    $c->stash->{template} = 'tokens/error.html';
}

sub token_too_old : Private {
    my ( $self, $c ) = @_;
    $c->stash->{token_not_found} = 1;
    $c->stash->{template} = 'auth/token.html';
}

__PACKAGE__->meta->make_immutable;

1;
