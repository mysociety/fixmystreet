package FixMyStreet::App::Controller::Admin::EmergencyMessage;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    unless ( $c->user->has_body_permission_to('emergency_message_edit') ) {
        $c->detach('/page_error_403_access_denied', []);
    }

    if ( $c->req->method eq 'POST' ) {
        $c->forward('/auth/check_csrf_token');

        my $emergency_message = $c->get_param('emergency_message');

        my $body = $c->cobrand->body;
        $body->set_extra_metadata(emergency_message => $emergency_message);
        $body->update;
    }

    $c->forward('/auth/get_csrf_token');

    $c->stash->{emergency_message} = $c->cobrand->emergency_message;
}

1;
