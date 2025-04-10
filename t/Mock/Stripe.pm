package t::Mock::Stripe;

use JSON::MaybeXS;
use Test::More;
use Web::Simple;
use LWP::Protocol::PSGI;

has json => (
    is => 'lazy',
    default => sub {
        JSON->new->pretty->allow_blessed->convert_blessed;
    },
);

sub output {
    my ($self, $response) = @_;
    my $json = $self->json->encode($response);
    return [ 200, [ 'Content-Type' => 'application/json' ], [ $json ] ];
}

sub dispatch_request {
    my $self = shift;

    sub (POST + /v1/checkout/sessions + %*) {
        my ($self, $args) = @_;
        like $args->{success_url}, qr{/parishes/pay_complete};
        is $args->{'line_items[0][price]'}, 'price';
        return $self->output({
            url => 'https://example.org/faq',
        });
    },

    sub (GET + /v1/checkout/sessions/*) {
        my ($self, $id) = @_;
        is $id, 'SESSIONID';
        return $self->output({
            customer => { email => 'test@example.com' },
            subscription => 'sub_ID',
        });
    },
}

LWP::Protocol::PSGI->register(t::Mock::Stripe->to_psgi_app, host => 'api.stripe.com');

__PACKAGE__->run_if_script;
