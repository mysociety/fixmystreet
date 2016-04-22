package t::Mock::Twitter;

use JSON::MaybeXS;
use Web::Simple;
use MooX::Types::MooseLike::Base qw(:all);

has json => (
    is => 'lazy',
    default => sub {
        JSON->new->pretty->allow_blessed->convert_blessed;
    },
);

sub dispatch_request {
    my $self = shift;

    sub (GET + /oauth/authenticate + ?*) {
        my ($self) = @_;
        return [ 200, [ 'Content-Type' => 'text/html' ], [ 'TwitteB login page' ] ];
    },

    sub (GET + /oauth/access_token + ?*) {
        my ($self) = @_;
        return [ 200, [ 'Content-Type' => 'text/plain' ], [ 'oauth_token=access_token&oauth_token_secret=secret' ] ];
    },

    sub (GET + /oauth/request_token + ?*) {
        my ($self) = @_;
        return [ 200, [ 'Content-Type' => 'text/plain' ], [ 'oauth_token=request-token&oauth_token_secret=secret&oauth_callback_confirmed=true' ] ];
    },

    sub (GET + /1.1/account/verify_credentials.json + ?*) {
        my ($self) = @_;
        my $data = {
            id => '987654321',
            name => 'Fiona Tester',
        };
        my $json = $self->json->encode($data);
        return [ 200, [ 'Content-Type' => 'text/html' ], [ $json ] ];
    },
}

__PACKAGE__->run_if_script;
