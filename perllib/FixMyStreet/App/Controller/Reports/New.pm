package FixMyStreet::App::Controller::Reports::New;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::Reports::New

=head1 DESCRIPTION

Create a new report, or complete a partial one.

=cut

sub report_new : Path : Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body(
        'Matched FixMyStreet::App::Controller::Reports::New in Reports::New.');
}

__PACKAGE__->meta->make_immutable;

1;
