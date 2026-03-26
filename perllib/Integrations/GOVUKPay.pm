=head1 NAME

Integrations::GOVUKPay - GOV.UK Pay REST API client

=head1 SYNOPSIS

    my $pay = Integrations::GOVUKPay->new({
        config => {
            api_key   => 'your-api-key',
            api_url   => 'https://publicapi.payments.service.gov.uk',
            log_ident => 'govukpay',
        },
    });

    # Create a payment
    my $result = $pay->create_payment({
        amount      => 2500,          # pence
        reference   => 'ORDER-001',
        description => 'Garden waste subscription',
        return_url  => 'https://example.com/pay_complete/123/token',
    });

    # Query payment status
    my $details = $pay->get_payment_details($payment_id);

=head1 DESCRIPTION

A thin Perl client for the GOV.UK Pay API, modelled after the existing
Integrations::SCP and Integrations::Adelante modules. Uses LWP::UserAgent
for HTTP and JSON::MaybeXS for serialisation.

API docs: L<https://docs.payments.service.gov.uk/>

=cut

package Integrations::GOVUKPay;

use Moo;
with 'FixMyStreet::Roles::Syslog';

use JSON::MaybeXS;
use LWP::UserAgent;
use HTTP::Request::Common;
use Try::Tiny;

has config => (
    is => 'ro',
    coerce => sub { return {} unless $_[0] },
);

has log_ident => (
    is => 'lazy',
    default => sub { $_[0]->config->{log_ident} || 'govukpay' },
);

has ua => (
    is => 'lazy',
    default => sub {
        LWP::UserAgent->new(
            timeout => 30,
            agent   => 'FixMyStreet-GOVUKPay/1.0',
        );
    },
);

has json => (
    is => 'lazy',
    default => sub { JSON::MaybeXS->new(utf8 => 1) },
);

sub _api_url {
    my $self = shift;
    return $self->config->{api_url} || 'https://publicapi.payments.service.gov.uk';
}

sub _headers {
    my $self = shift;
    return (
        'Authorization' => 'Bearer ' . $self->config->{api_key},
        'Content-Type'  => 'application/json',
        'Accept'        => 'application/json',
    );
}

=head2 create_payment(\%args)

Create a new payment. Required keys in C<%args>:

=over

=item amount - amount in pence (integer)

=item reference - your unique payment reference

=item description - human-readable description

=item return_url - URL to redirect payer after completion

=back

Optional keys: C<email>, C<metadata> (hashref).

Returns a hashref with C<payment_id> and C<next_url> on success,
or dies with an error message on failure.

=cut

sub create_payment {
    my ($self, $args) = @_;

    my $payload = {
        amount      => $args->{amount},
        reference   => $args->{reference},
        description => $args->{description},
        return_url  => $args->{return_url},
    };
    $payload->{email} = $args->{email} if $args->{email};
    $payload->{metadata} = $args->{metadata} if $args->{metadata};

    $self->log("create_payment: ref=$args->{reference} amount=$args->{amount}");

    my $url = $self->_api_url . '/v1/payments';
    my $body = $self->json->encode($payload);

    my $req = HTTP::Request->new('POST', $url);
    $req->header('Authorization' => 'Bearer ' . $self->config->{api_key});
    $req->header('Content-Type'  => 'application/json');
    $req->header('Accept'        => 'application/json');
    $req->content($body);

    $self->log("create_payment URL: $url");
    $self->log("create_payment body: $body");

    my $response = $self->ua->request($req);
    my $data = $self->_decode_response($response, 'create_payment');

    my $payment_id = $data->{payment_id}
        or die "GOV.UK Pay: no payment_id in response\n";
    my $next_url   = $data->{_links}{next_url}{href}
        or die "GOV.UK Pay: no next_url in response\n";

    $self->log("create_payment: payment_id=$payment_id");

    return {
        payment_id => $payment_id,
        next_url   => $next_url,
    };
}

=head2 get_payment_details($payment_id)

Fetch the full payment resource.  Uses C<GET /v1/payments/{PAYMENT_ID}>.
This endpoint is strongly consistent.

Returns the decoded JSON hashref, or dies on error.

=cut

sub get_payment_details {
    my ($self, $payment_id) = @_;

    $self->log("get_payment_details: $payment_id");

    my $url = $self->_api_url . '/v1/payments/' . $payment_id;
    my $req = HTTP::Request->new('GET', $url);
    $req->header($self->_headers);

    my $response = $self->ua->request($req);
    return $self->_decode_response($response, 'get_payment_details');
}

=head2 get_payment_status($payment_id)

Convenience method: returns the status string for a payment.

Possible values: C<created>, C<started>, C<submitted>, C<capturable>,
C<success>, C<failed>, C<cancelled>, C<error>.

=cut

sub get_payment_status {
    my ($self, $payment_id) = @_;

    my $details = $self->get_payment_details($payment_id);
    return $details->{state}{status} || 'unknown';
}

=head2 search_payments(\%params)

Search payments using C<GET /v1/payments> (eventually consistent).
Passes all keys in C<%params> as query parameters.

Common parameters: C<reference>, C<state>, C<from_date>, C<to_date>,
C<page>, C<display_size>.

Returns the decoded JSON hashref including C<results>, C<total>, C<count>.

=cut

sub search_payments {
    my ($self, $params) = @_;
    $params ||= {};

    $self->log("search_payments: " . join(', ', map { "$_=$params->{$_}" } keys %$params));

    my $uri = URI->new($self->_api_url . '/v1/payments');
    $uri->query_form(%$params);

    my $req = HTTP::Request->new('GET', $uri);
    $req->header($self->_headers);

    my $response = $self->ua->request($req);
    return $self->_decode_response($response, 'search_payments');
}

# Internal: decode an HTTP response or die with details
sub _decode_response {
    my ($self, $response, $method) = @_;

    my $content = $response->decoded_content || '';
    $self->log("$method response: " . $response->status_line);
    $self->log($content) if $content;

    unless ($response->is_success) {
        die "GOV.UK Pay $method failed: " . $response->status_line . " " . $content . "\n";
    }

    return $self->json->decode($content);
}

1;
