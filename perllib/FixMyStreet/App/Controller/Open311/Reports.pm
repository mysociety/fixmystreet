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

sub receive : Regex('^open311/v2/requests.(xml|json)$') : Args(0) {
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

    # XXX
    # params from spec are:
    #
    # service_code
    # lat
    # long
    # description
    # media_url
    #
    # and then we'd need attributes for:
    # request id
    #
    my $request = {
        media_url => $c->get_param('media_url'),
        external_status_code => $c->get_param('attributes[service_request_id]'),
    };
    foreach (qw(service_code lat long description)) {
        $request->{$_} = $c->get_param($_) || $c->detach('bad_request', [ $_ ]);
    }

    my $problems = Open311::GetServiceRequests->new(
        system_user => $body->comment_user,
        current_body => $body,
    );

    my $p = $problems->find_problem($request);
    $c->detach('bad_request', [ 'already exists' ]) if $p;

    $p = $problems->process_request($request);

    my $data = { service_requests => { requests => { service_request_id => $p->id } } };

    $c->forward('/open311/format_output', [ $data ]);
}

sub bad_request : Private {
    my ($self, $c, $comment) = @_;
    $c->response->status(400);
    $c->forward('/open311/format_output', [ { errors => { code => 400, description => "Bad request: $comment" } } ]);
}

__PACKAGE__->meta->make_immutable;

1;
