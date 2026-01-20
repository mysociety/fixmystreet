package FixMyStreet::App::Controller::Api;

use Moose;
use namespace::autoclean;
use JSON::MaybeXS;
use Try::Tiny;

BEGIN { extends 'Catalyst::Controller' }

has api_username => (isa => 'Str', is => 'rw', default => '');
has api_password => (isa => 'Str', is => 'rw', default => '');
has api_config => (isa => 'HashRef', is => 'rw', lazy => 1, default => sub {{}});
has post_data => (isa => 'HashRef', is => 'rw', default => sub {{}});

sub json_response : Private('/api/json_response') {
    my ($self, $c, $code, $message) = @_;

    my $body = {
        message => $message || $self->_default_json_responses($code),
    };

    $c->response->status($code);
    $c->response->body(encode_json($body));
}

sub authorise : Private('/api/authorise') {
    my ($self, $c) = @_;

    try {
        if (
            ($self->api_password && $self->api_config->{password} && $self->api_username && $self->api_config->{username})
            && ($self->api_password eq $self->api_config->{password} && $self->api_username eq $self->api_config->{username})
        ) {
            return;
        }
        $c->detach;
    } catch {
        $c->detach('/api/json_response', [401]);
    }
}

sub get_json_post_data : Private('/api/get_post_data') {
    my ($self, $c) =  @_;

    try {
        $c->detach unless $c->req->body;
        my $file = $c->req->body;
        my $text = join('', <$file>);
        $self->post_data(decode_json($text));
    } catch {
        $c->detach('/api/json_response', [406]);
    }
}

sub _default_json_responses {
    my ($self, $code) = @_;

    my $responses = {
        200 => 'OK',
        400 => 'Bad request',
        401 => 'Unauthorised',
        404 => 'Not found',
        405 => 'Method not allowed',
        406 => 'Not acceptable',
    };

    return $responses->{$code} || '';
}

return 1;
