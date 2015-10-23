package FixMyStreet::App::Controller::Status;
use Moose;
use namespace::autoclean;

use HTTP::Negotiate;
use JSON;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

FixMyStreet::App::Controller::Status - Catalyst Controller

=head1 DESCRIPTION

Status page Catalyst Controller.

=head1 METHODS

=cut

sub index_json : Path('/status.json') : Args(0) {
    my ($self, $c) = @_;
    $c->forward('index', [ 'json' ]);
}

sub index : Path : Args(0) {
    my ($self, $c, $format) = @_;

    # Fetch summary stats from admin front page
    $c->forward('/admin/index');

    # Fetch git version
    $c->forward('/admin/config_page');

    my $chosen = $format;
    unless ($chosen) {
        my $variants = [
            ['html', undef, 'text/html', undef, undef, undef, undef],
            ['json', undef, 'application/json', undef, undef, undef, undef],
        ];
        $chosen = HTTP::Negotiate::choose($variants, $c->req->headers);
        $chosen = 'html' unless $chosen;
    }

    # TODO Perform health checks here

    if ($chosen eq 'json') {
        $c->res->content_type('application/json; charset=utf-8');
        my $data = {
            version => $c->stash->{git_version},
            reports => $c->stash->{total_problems_live},
            updates => $c->stash->{comments}{confirmed},
            alerts_confirmed => $c->stash->{alerts}{1},
            alerts_unconfirmed => $c->stash->{alerts}{0},
            questionnaires_sent => $c->stash->{questionnaires}{total},
            questionnaires_answered => $c->stash->{questionnaires}{1},
            bodies => $c->stash->{total_bodies},
            contacts => $c->stash->{contacts}{total},
        };
        my $body = JSON->new->utf8(1)->pretty->encode($data);
        $c->res->body($body);
    }

    return 1;
}

__PACKAGE__->meta->make_immutable;

1;
