package FixMyStreet::App::Controller::Root;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

__PACKAGE__->config( namespace => '' );

=head1 NAME

FixMyStreet::App::Controller::Root - Root Controller for FixMyStreet::App

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=head2 auto

Set up general things for this instance

=cut

sub auto : Private {
    my ( $self, $c ) = @_;

    # decide which cobrand this request should use
    $c->setup_request();

    return 1;
}

=head2 index

Home page.

If request includes certain parameters redirect to '/around' - this is to
preserve old behaviour.

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;

    my @old_param_keys = ( 'pc', 'x', 'y', 'e', 'n', 'lat', 'lon' );
    my %old_params = ();

    foreach my $key (@old_param_keys) {
        my $val = $c->req->param($key);
        next unless $val;
        $old_params{$key} = $val;
    }

    if ( scalar keys %old_params ) {
        my $around_uri = $c->uri_for( '/around', \%old_params );
        $c->res->redirect($around_uri);
        return;
    }

}

=head2 default

Forward to the standard 404 error page

=cut

sub default : Path {
    my ( $self, $c ) = @_;
    $c->detach('/page_error_404_not_found');
}

=head2 page_error_404_not_found, page_error_410_gone

    $c->detach( '/page_error_404_not_found', [$error_msg] );
    $c->detach( '/page_error_410_gone',      [$error_msg] );

Display a 404 (not found) or 410 (gone) page. Pass in an optional error message in an arrayref.

=cut

sub page_error_404_not_found : Private {
    my ( $self, $c, $error_msg ) = @_;
    $c->stash->{template}  = 'errors/page_error_404_not_found.html';
    $c->stash->{error_msg} = $error_msg;
    $c->response->status(404);
}

sub page_error_410_gone : Private {
    my ( $self, $c, $error_msg ) = @_;
    $c->stash->{template}  = 'index.html';
    $c->stash->{error} = $error_msg;
    $c->response->status(410);
}

=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {
}

__PACKAGE__->meta->make_immutable;

1;
