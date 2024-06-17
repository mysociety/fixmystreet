package FixMyStreet::App::Controller::Waste::Whitespace;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

with 'FixMyStreet::Roles::Syslog';

use utf8;

has log_ident => (
    is => 'ro',
    default => sub {
        my $feature = 'whitespace';
        my $features = FixMyStreet->config('COBRAND_FEATURES');
        return unless $features && ref $features eq 'HASH';
        return unless $features->{$feature} && ref $features->{$feature} eq 'HASH';
        my $f = $features->{$feature}->{_fallback};
        return $f->{log_ident};
    }
);

sub receive_whitespace_event_notification : Path('/waste/whitespace') : Args(0) {
    my ($self, $c) = @_;

    my %headers = $c->req->headers->flatten;
    $self->log($c->req->method);
    $self->log(\%headers);
    $self->log($c->req->parameters);
    if ($c->req->body) {
        my $soap = join('', $c->req->body->getlines);
        $self->log($soap);
    } else {
        $self->log('No body');
    }

    $c->response->status(200);
    $c->response->body('OK');
}

1;
