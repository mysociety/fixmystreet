package FixMyStreet::App::Controller::Auth::Phone;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use FixMyStreet::SMS;

=head1 NAME

FixMyStreet::App::Controller::Auth::Phone - Catalyst Controller

=head1 DESCRIPTION

Controller for phone SMS based authentication

=head1 METHODS

=head2 code

Handle the submission of a code sent by text to a mobile number.

=cut

sub code : Path('') {
    my ( $self, $c, $scope, $success_action ) = @_;
    $c->stash->{template} = 'auth/smsform.html';
    $scope ||= 'phone_sign_in';
    $success_action ||= '/auth/process_login';

    my $token = $c->stash->{token} = $c->get_param('token');
    my $code = $c->get_param('code') || '';

    my $data = $c->stash->{token_data} = $c->forward('/auth/get_token', [ $token, $scope ]) || return;

    $c->stash->{incorrect_code} = 1, return if $data->{code} ne $code;

    $c->detach( $success_action, [ $data, 'phone' ] );
}

=head2 sign_in

When signing in with a mobile phone number, we are sent here.
This sends a text to that number with a confirmation code,
and sets up the token/etc to deal with the response.

=cut

sub sign_in : Private {
    my ( $self, $c, $parsed ) = @_;

    unless ($parsed->{phone}) {
        $c->stash->{username_error} = 'other_phone';
        return;
    }

    unless ($parsed->{may_be_mobile}) {
        $c->stash->{username_error} = 'nonmobile';
        return;
    }

    (my $number = $parsed->{phone}->format) =~ s/\s+//g;

    if ( FixMyStreet->config('SIGNUPS_DISABLED')
         && !$c->model('DB::User')->find({ phone => $number })
         && !$c->stash->{current_user} # don't break the change phone flow
    ) {
        $c->stash->{template} = 'auth/token.html';
        return;
    }

    my $user_params = {};
    $user_params->{password} = $c->get_param('password_register')
        if $c->get_param('password_register');
    my $user = $c->model('DB::User')->new( $user_params );

    my $token_data = {
        phone => $number,
        r => $c->get_param('r'),
        name => $c->get_param('name'),
        password => $user->password,
    };
    if ($c->stash->{current_user}) {
        $token_data->{old_user_id} = $c->stash->{current_user}->id;
        $token_data->{r} = 'auth/change_phone/success';
    }

    $c->forward('send_token', [ $token_data, 'phone_sign_in', $number ]);
}

sub send_token : Private {
    my ( $self, $c, $token_data, $token_scope, $to ) = @_;

    my $result = FixMyStreet::SMS->send_token($token_data, $token_scope, $to);
    if ($result->{error}) {
        $c->log->debug("Failure sending text containing code *$result->{random}*");
        $c->stash->{sms_error} = $result->{error};
        $c->stash->{username_error} = 'sms_failed';
        return;
    }
    $c->stash->{token} = $result->{token};
    $c->log->debug("Sending text containing code *$result->{random}*");
    $c->stash->{template} = 'auth/smsform.html';
}

__PACKAGE__->meta->make_immutable;

1;
