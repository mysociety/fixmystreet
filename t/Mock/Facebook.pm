package t::Mock::Facebook;

use JSON::MaybeXS;
use Web::Simple;
use MooX::Types::MooseLike::Base qw(:all);

has json => (
    is => 'lazy',
    default => sub {
        JSON->new->pretty->allow_blessed->convert_blessed;
    },
);

has returns_email => (
    is => 'rw',
    isa => Bool,
    default => 1,
);

sub dispatch_request {
    my $self = shift;

    sub (GET + /v3.1/dialog/oauth + ?*) {
        my ($self) = @_;
        return [ 200, [ 'Content-Type' => 'text/html' ], [ 'FB login page' ] ];
    },

    sub (GET + /v3.1/oauth/access_token + ?*) {
        my ($self) = @_;
        return [ 200, [ 'Content-Type' => 'application/json' ], [ '{"access_token": "access_token"}' ] ];
    },

    sub (GET + /me + ?fields=) {
        my ($self, $fields) = @_;
        my $data = {
            id => '123456789',
            name => 'Fiona Tester',
        };
        $data->{email} = 'facebook@example.org' if $self->returns_email;
        my $json = $self->json->encode($data);
        return [ 200, [ 'Content-Type' => 'text/html' ], [ $json ] ];
    },

    sub (GET + /search + ?q=) {
        my ($self, $q) = @_;
        my $response = $self->query($q);
        my $json = $self->json->encode($response);
        return [ 200, [ 'Content-Type' => 'application/json' ], [ $json ] ];
    },
}

__PACKAGE__->run_if_script;
