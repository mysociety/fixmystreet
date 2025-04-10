package Integrations::Stripe;

use v5.14;
use warnings;
use Moo;
use HTTP::Request::Common;
use JSON::MaybeXS;
use LWP::UserAgent;

has config => ( is => 'ro' );

has ua => (
    is => 'lazy',
    default => sub {
        my $self = shift;
        my $ua = LWP::UserAgent->new;
        return $ua;
    }
);

sub request {
    my ($self, $method, $url, $params) = @_;
    my $cfg = $self->config;

    my $uri = URI->new("https://api.stripe.com/v1/");
    $uri->path("/v1/$url");

    my $req;
    if ($method eq 'GET') {
        $uri->query_form($params) if $params;
        $req = GET $uri->as_string;
    } elsif ($method eq 'POST') {
        $req = POST $uri->as_string, $params;
    }
    $req->authorization_basic($cfg->{secret_key}, '');

    my $res = $self->ua->request($req);
    my $data = decode_json($res->decoded_content);
    return $data;
}

1;
