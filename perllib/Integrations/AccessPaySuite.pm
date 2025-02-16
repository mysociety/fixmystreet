=head1 NAME

Integrations::AccessPaySuite - Client for the Access Paysuite API

=head1 SYNOPSIS

    my $client = Integrations::AccessPaySuite->new(
        config => {
            endpoint => 'https://ddcms.accesspaysuite.com',
            client_code => 'CLIENT123',
            api_key => 'your-api-key'
        }
    );

    # Create a customer
    my $customer = $client->create_customer({
        name => 'John Doe',
        email => 'john@example.com'
    });

    # Set up a direct debit
    my $contract = $client->create_contract($customer->{id}, {
        account_number => '12345678',
        sort_code => '123456'
    });

=head1 DESCRIPTION

This module provides a Perl interface to the Access Paysuite API.
It handles authentication, request building, and response parsing, providing
a simple interface for managing direct debit customers, contracts, and payments.

=cut

package Integrations::AccessPaySuite;

use Moo;
use strict;
use warnings;

use LWP::UserAgent;
use HTTP::Request::Common;
use JSON::MaybeXS;
use URI::Escape;
use URI;

# Configuration attributes
has config => (
    is => 'ro',
    required => 1,
);

has endpoint => (
    is => 'lazy',
    default => sub {
        my $self = shift;
        my $endpoint = $self->config->{endpoint};
        $endpoint =~ s{/$}{};  # Remove trailing slash if present
        return $endpoint . '/api/v3';
    }
);

has client_code => (
    is => 'lazy',
    default => sub {
        my $self = shift;
        return $self->config->{client_code};
    }
);

has page_size => (
    is => 'rw',
    default => 50,
);

has ua => (
    is => 'lazy',
    default => sub {
        my $self = shift;
        return LWP::UserAgent->new;
    }
);

# Private request handling methods
sub headers {
    my $self = shift;

    return {
        'Accept' => 'application/json',
        'Content-Type' => 'application/x-www-form-urlencoded',
        'User-Agent' => 'WasteWorks by SocietyWorks (swtech@societyworks.org)',
        'ApiKey' => $self->config->{api_key},
    };
}

sub build_path {
    my ($self, $path) = @_;
    $path =~ s{^/}{};  # Remove leading slash if present
    return sprintf("/client/%s/%s", $self->client_code, $path);
}

sub build_form_data {
    my ($self, $params) = @_;
    return '' unless $params && %$params;

    my $uri = URI->new('');
    $uri->query_form($params);
    return $uri->query;
}

sub build_request_url {
    my ($self, $method, $path, $data) = @_;
    my $url = $self->endpoint . $self->build_path($path);

    if ($data && ($method eq 'GET' || $method eq 'DELETE')) {
        my $query = $self->build_form_data($data);
        $url .= '?' . $query if $query;
    }

    return $url;
}

sub create_request {
    my ($self, $method, $url, $data) = @_;
    my $content = ($method eq 'POST' || $method eq 'PUT') ? $self->build_form_data($data) : '';

    return HTTP::Request->new(
        $method => $url,
        HTTP::Headers->new(%{ $self->headers }),
        $content
    );
}

sub parse_response {
    my ($self, $resp) = @_;
    return {} if $resp->code == 204;

    my $response_content;
    eval {
        $response_content = decode_json($resp->content);
    };
    if ($@) {
        # If content isn't valid JSON, return raw content
        $response_content = $resp->content;
    }

    if ($resp->is_success) {
        return $response_content;
    }

    # Return structured error, handling both JSON and non-JSON responses
    my $error_message;
    if (ref $response_content eq 'HASH') {
        $error_message = $response_content->{Message};
    } else {
        $error_message = $response_content;
    }

    return {
        error => $error_message || "API call failed",
        code => $resp->code,
        content => $response_content,
    };
}

sub call {
    my ($self, $method, $path, $data) = @_;
    my $url = $self->build_request_url($method, $path, $data);
    my $req = $self->create_request($method, $url, $data);
    my $resp = $self->ua->request($req);
    return $self->parse_response($resp);
}

# Customer API methods
sub get_customer {
    my ($self, $customer_ref) = @_;
    return $self->call('GET', "customer/$customer_ref");
}

sub get_customer_by_customer_ref {
    my ($self, $customer_ref) = @_;
    my $resp = $self->call('GET', "customer", { customerRef => $customer_ref });
    return $resp->{Customers}->[0];
}

sub create_customer {
    my ($self, $data) = @_;
    return $self->call('POST', "customer", $data);
}

# Contract (mandate) API methods
sub get_contract {
    my ($self, $contract_ref) = @_;
    return $self->call('GET', "contract/$contract_ref");
}

sub create_contract {
    my ($self, $customer_ref, $data) = @_;
    return $self->call('POST', "customer/$customer_ref/contract", $data);
}

sub cancel_contract {
    my ($self, $contract_ref) = @_;
    return $self->call('DELETE', "contract/$contract_ref");
}

1;
