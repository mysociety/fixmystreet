package FixMyStreet::App::Controller::Admin::Teams;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }


sub begin : Private {
    my ( $self, $c ) = @_;

    $c->forward('/admin/begin');
}

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    my $user = $c->user;

    if ($user->is_superuser) {
        $c->forward('/admin/fetch_all_bodies');
    } elsif ( $user->from_body ) {
        $c->forward('/admin/load_user_body', [ $user->from_body->id, 'user_edit' ]);
        $c->res->redirect( $c->uri_for( '', $c->stash->{body}->id ) );
    } else {
        $c->detach( '/page_error_404_not_found' );
    }
}

sub search : Path : Args(1) {
    my ($self, $c, $body_id) = @_;

    $c->forward('/admin/load_user_body', [ $body_id, 'user_edit' ]);
    $c->forward('/admin/fetch_contacts');
    $c->forward('/admin/fetch_body_areas', [ $c->stash->{body} ]);

}

__PACKAGE__->meta->make_immutable;

1;
