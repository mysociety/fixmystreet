package FixMyStreet::App::Controller::Tokens;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use FixMyStreet::Alert;

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
    my $problem_id = $auth_token->data;
    my $problem = $c->model('DB::Problem')->find( { id => $problem_id } )
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
    my $alert_id =
      FixMyStreet::Alert::create( $problem->user->email, 'new_updates',
        $problem->cobrand, $problem->cobrand_data, $problem_id );
    FixMyStreet::Alert::confirm($alert_id);

    # log the problem creation user in to the site
    $c->authenticate( { email => $problem->user->email }, 'no_password' );

    return 1;
}

=head2 redirect_to_partial_problem

    /P/...

Redirect user to continue filling in a partial problem.

=cut

sub redirect_to_partial_problem : Path('/L') {
    my ( $self, $c, $token_code ) = @_;

    my $url = $c->uri_for( "/reports/new", { partial => $token_code } );
    return $c->res->redirect( $url );
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
    $c->stash->{template} = 'tokens/error.html';
    $c->detach;
}

__PACKAGE__->meta->make_immutable;

1;
