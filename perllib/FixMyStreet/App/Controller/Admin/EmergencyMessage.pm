package FixMyStreet::App::Controller::Admin::EmergencyMessage;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    # Normal users can only edit message for the current body.
    $c->detach('edit_emergency_message', [$c->user->from_body]) unless $c->user->is_superuser;

    # Superusers can see a list of all bodies with emergency messages.
    my @bodies = $c->model('DB::Body')->search(undef, { order_by => [ 'name', 'id' ] });
    $c->stash->{bodies} = \@bodies;
}

sub edit :Local :Args(1) {
    my ( $self, $c, $body_id ) = @_;

    # Only superusers can edit arbitrary bodies
    $c->detach('/page_error_403_access_denied', []) unless $c->user->is_superuser;

    my $body = $c->model('DB::Body')->find($body_id)
        || $c->detach( '/page_error_404_not_found', [] );

    $c->detach('edit_emergency_message', [$body]);
}

sub edit_emergency_message :Private {
    my ( $self, $c, $body ) = @_;

    if ( $c->req->method eq 'POST' ) {
        $c->forward('/auth/check_csrf_token');

        my $emergency_message = FixMyStreet::Template::sanitize($c->get_param('emergency_message'));
        $emergency_message =~ s/^\s+|\s+$//g;

        if ( $emergency_message ) {
            $body->set_extra_metadata(emergency_message => $emergency_message);
        } else {
            $body->unset_extra_metadata('emergency_message');
        }

        $body->update;
        $c->stash->{status_message} = _('Updated!');
    }

    $c->forward('/auth/get_csrf_token');
    $c->stash->{emergency_message} = $body->get_extra_metadata('emergency_message');

    $c->stash->{template} = 'admin/emergencymessage/edit.html';
}

1;
