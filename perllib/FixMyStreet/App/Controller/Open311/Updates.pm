package FixMyStreet::App::Controller::Open311::Updates;

use utf8;
use Moose;
use namespace::autoclean;
use Open311::GetServiceRequestUpdates;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::Open311::Updates - Catalyst Controller

=head1 DESCRIPTION

=head1 METHODS

=cut

sub receive : Regex('^open311/v2/servicerequestupdates.(xml|json)$') : Args(0) {
    my ( $self, $c ) = @_;
    $c->stash->{format} = $c->req->captures->[0];

    $c->detach('bad_request', [ 'POST' ]) unless $c->req->method eq 'POST';

    my $body;
    if ($c->cobrand->can('council_area_id')) {
        $body = $c->cobrand->body;
    } else {
        $body = $c->model('DB::Body')->find({ id => $c->get_param('jurisdiction_id') });
    }
    $c->detach('bad_request', ['jurisdiction_id']) unless $body;

    my $key = $c->get_param('api_key') || '';
    my $token = $c->cobrand->feature('open311_token') || '';
    $c->detach('bad_request', [ 'api_key' ]) unless $key && $key eq $token;

    my $request = {
        media_url => $c->get_param('media_url'),
        external_status_code => $c->get_param('external_status_code'),
    };
    foreach (qw(service_request_id update_id updated_datetime status description)) {
        $request->{$_} = $c->get_param($_) || $c->detach('bad_request', [ $_ ]);
    }

    $c->forward('process_update', [ $body, $request ]);
}

sub process_update : Private {
    my ($self, $c, $body, $request) = @_;

    my $updates = Open311::GetServiceRequestUpdates->new(
        system_user => $body->comment_user,
        current_body => $body,
    );

    my $p = $updates->find_problem($request);
    $c->detach('bad_request', [ 'not found' ]) unless $p;

    $c->forward('check_existing', [ $p, $request, $updates ]);

    my $comment = $updates->process_update($request, $p);

    my $data = { service_request_updates => { update_id => $comment->id } };

    $c->forward('/open311/format_output', [ $data ]);
}

sub check_existing : Private {
    my ($self, $c, $p, $request, $updates) = @_;

    my $comment = $p->comments->search( { external_id => $request->{update_id} } )->first;
    $c->detach('bad_request', [ 'already exists' ]) if $comment;
}

sub bad_request : Private {
    my ($self, $c, $comment) = @_;
    $c->response->status(400);
    $c->forward('/open311/format_output', [ { errors => { code => 400, description => "Bad request: $comment" } } ]);
}

__PACKAGE__->meta->make_immutable;

1;

