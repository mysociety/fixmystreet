package FixMyStreet::App::Controller::Offline;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::Offline - Catalyst Controller

=head1 DESCRIPTION

Offline pages Catalyst Controller.

=head1 METHODS

=cut

sub have_appcache : Private {
    my ($self, $c) = @_;
    return $c->user_exists && $c->user->has_body_permission_to('planned_reports')
        && !($c->user->is_superuser && FixMyStreet->staging_flag('enable_appcache', 0));
}

sub manifest : Path("/offline/appcache.manifest") {
    my ($self, $c) = @_;
    unless ($c->forward('have_appcache')) {
        $c->response->status(404);
        $c->response->body('NOT FOUND');
    }
    $c->res->content_type('text/cache-manifest; charset=utf-8');
    $c->res->header(Cache_Control => 'no-cache, no-store');
}

sub appcache : Path("/offline/appcache") {
    my ($self, $c) = @_;
    $c->detach('/page_error_404_not_found', []) if keys %{$c->req->params};
    unless ($c->forward('have_appcache')) {
        $c->response->status(404);
        $c->response->body('NOT FOUND');
    }
}

__PACKAGE__->meta->make_immutable;

1;
