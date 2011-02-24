package FixMyStreet::App::Controller::About;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::About - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 about

Show the 'about us' page.

=cut

sub about : Path : Args(0) {
    my ( $self, $c ) = @_;

    # don't need to do anything here - should just pass through.
}

__PACKAGE__->meta->make_immutable;

1;
