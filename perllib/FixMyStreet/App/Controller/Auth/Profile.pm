package FixMyStreet::App::Controller::Auth::Profile;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::Auth::Profile - Catalyst Controller

=head1 DESCRIPTION

Controller for all the authentication profile related pages - changing email,
password.

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

__PACKAGE__->meta->make_immutable;

1;
