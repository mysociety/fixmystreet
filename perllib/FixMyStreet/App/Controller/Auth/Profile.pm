package FixMyStreet::App::Controller::Auth::Profile;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

use mySociety::AuthToken;

=head1 NAME

FixMyStreet::App::Controller::Auth::Profile - Catalyst Controller

=head1 DESCRIPTION

Controller for all the authentication profile related pages - adding/ changing/
verifying email, phone, password.

=head1 METHODS

=cut

sub auto {
    my ( $self, $c ) = @_;

    $c->detach( '/auth/redirect' ) unless $c->user;

    return 1;
}

=head2 change_password

Let the user change their password.

=cut

sub change_password : Path('/auth/change_password') {
    my ( $self, $c ) = @_;

    $c->stash->{template} = 'auth/change_password.html';

    $c->forward('/auth/get_csrf_token');

    # If not a post then no submission
    return unless $c->req->method eq 'POST';

    $c->forward('/auth/check_csrf_token');

    # get the passwords
    my $new = $c->get_param('new_password') // '';
    my $confirm = $c->get_param('confirm') // '';

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

=head2 change_email

Let the user change their email.

=cut

sub change_email : Path('/auth/change_email') {
    my ( $self, $c ) = @_;

    $c->stash->{template} = 'auth/change_email.html';

    $c->forward('/auth/get_csrf_token');

    # If not a post then no submission
    return unless $c->req->method eq 'POST';

    $c->forward('/auth/check_csrf_token');
    $c->stash->{current_user} = $c->user;
    $c->stash->{email_template} = 'change_email.txt';
    $c->forward('/auth/email_sign_in', [ $c->get_param('email') ]);
}

sub change_phone : Path('/auth/change_phone') {
    my ( $self, $c ) = @_;

    $c->stash->{template} = 'auth/change_phone.html';

    $c->forward('/auth/get_csrf_token');

    # If not a post then no submission
    return unless $c->req->method eq 'POST';

    $c->forward('/auth/check_csrf_token');
    $c->stash->{current_user} = $c->user;

    my $phone = $c->stash->{username} = $c->get_param('username') || '';
    my $parsed = FixMyStreet::SMS->parse_username($phone);

    # Allow removal of phone number, if we have verified email
    if (!$phone && !$c->stash->{verifying} && $c->user->email_verified) {
        $c->user->update({ phone => undef, phone_verified => 0 });
        $c->flash->{flash_message} = _('You have successfully removed your phone number.');
        $c->res->redirect('/my');
        $c->detach;
    }

    $c->stash->{username_error} = 'missing_phone', return unless $phone;
    $c->stash->{username_error} = 'other_phone', return unless $parsed->{phone};

    # If we've not used a mobile and we're not specifically verifying,
    # and phone isn't our only verified way of logging in,
    # then allow change of number (for e.g. landline).
    if (!FixMyStreet->config('SMS_AUTHENTICATION') || (!$parsed->{may_be_mobile} && !$c->stash->{verifying} && $c->user->email_verified)) {
        $c->user->update({ phone => $phone, phone_verified => 0 });
        $c->flash->{flash_message} = _('You have successfully added your phone number.');
        $c->res->redirect('/my');
        $c->detach;
    }

    $c->forward('/auth/phone/sign_in', [ $parsed ]);
}

sub verify_item : Path('/auth/verify') : Args(1) {
    my ( $self, $c, $type ) = @_;
    $c->stash->{verifying} = 1;
    $c->detach("change_$type");
}

sub change_email_success : Path('/auth/change_email/success') {
    my ( $self, $c ) = @_;
    $c->flash->{flash_message} = _('You have successfully confirmed your email address.');
    $c->res->redirect('/my');
}

sub change_phone_success : Path('/auth/change_phone/success') {
    my ( $self, $c ) = @_;
    $c->flash->{flash_message} = _('You have successfully verified your phone number.');
    $c->res->redirect('/my');
}

sub generate_token : Path('/auth/generate_token') {
    my ($self, $c) = @_;

    $c->detach( '/page_error_403_access_denied', [] )
        unless $c->user and ( $c->user->is_superuser or $c->user->from_body );

    $c->stash->{template} = 'auth/generate_token.html';
    $c->forward('/auth/get_csrf_token');

    if ($c->req->method eq 'POST') {
        $c->forward('/auth/check_csrf_token');
        my $token = mySociety::AuthToken::random_token();
        $c->user->set_extra_metadata('access_token', $token);
        $c->user->update();
        $c->stash->{token_generated} = 1;
    }

    $c->stash->{existing_token} = $c->user->get_extra_metadata('access_token');
}

__PACKAGE__->meta->make_immutable;

1;
