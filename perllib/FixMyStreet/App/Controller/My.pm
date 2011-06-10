package FixMyStreet::App::Controller::My;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::My - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub my : Path : Args(0) {
    my ( $self, $c ) = @_;

    # FIXME - handle not being logged in more elegantly
    unless ( $c->user ) {
        $c->res->redirect( $c->uri_for('/auth') );
        $c->detach;
    }

}

__PACKAGE__->meta->make_immutable;

1;
