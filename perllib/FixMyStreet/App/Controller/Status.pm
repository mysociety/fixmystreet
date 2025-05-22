package FixMyStreet::App::Controller::Status;
use Moose;
use namespace::autoclean;

use HTTP::Negotiate;
use JSON::MaybeXS;
use Try::Tiny;
use Time::HiRes;

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

    # Workaround that the admin summary page is only displayed to Zurich
    # superusers. It doesn't have anything sensitive
    $c->stash->{admin_type} = 'super';
    # Fetch summary stats from admin front page
    $c->forward('/admin/stats/gather');

    # Fetch git version
    $c->forward('/admin/config/git_version');

    my $chosen = $format;
    unless ($chosen) {
        my $variants = [
            ['html', undef, 'text/html', undef, undef, undef, undef],
            ['json', undef, 'application/json', undef, undef, undef, undef],
        ];
        $chosen = HTTP::Negotiate::choose($variants, $c->req->headers);
        $chosen = 'html' unless $chosen;
    }


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
            bodies => scalar @{$c->stash->{bodies}},
            contacts => $c->stash->{contacts}{total},
        };
        my $body = JSON->new->utf8(1)->pretty->encode($data);
        $c->res->body($body);
    }

    return 1;
}

sub health : Path('health') : Args(0) {
    my ($self, $c) = @_;

    # Just do a very simple and inexpensive query to confirm DB connectivity
    # and log if it took longer than 1 second.

    my $threshold = 1; # seconds
    my $t1 = Time::HiRes::time();

    my $id = try {
        $c->model('DB::Problem')->search(undef, {
            columns => [ "id" ],
            rows => 1,
            order_by => { -desc => 'id' },
        })->first->id;
    } catch {
        $c->log->info("Health check DB lookup failed: $_");
        undef;
    };

    my $t2 = Time::HiRes::time();
    $c->log->info("Health check DB lookup took " . ($t2 - $t1) . " seconds")
        if ($t2 > $t1 + $threshold);

    $c->res->content_type('text/plain; charset=utf-8');
    $c->res->headers->header('Cache-Control' => 'max-age=0');
    if ($id) {
        $c->res->body("OK: $id");
    } else {
        $c->response->status("500");
        $c->res->body("ERROR: Couldn't get last problem ID from DB");
    }
}


__PACKAGE__->meta->make_immutable;

1;
