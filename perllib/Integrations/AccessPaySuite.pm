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
with 'FixMyStreet::Roles::Syslog';

use LWP::UserAgent;
use HTTP::Request::Common;
use JSON::MaybeXS;
use URI::Escape;
use URI;
use Data::Dumper;

has log_ident => (
    is => 'lazy',
    default => sub { $_[0]->config->{log_ident}; },
);

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

    if ($data && ($method eq 'GET' || $method eq 'DELETE' || $method eq 'PATCH')) {
        my $query = $self->build_form_data($data);
        $url .= '?' . $query if $query;
    }

    return $url;
}

sub create_request {
    my ($self, $method, $url, $data) = @_;

    my $headers = $self->headers();

    return HTTP::Request::Common->can($method)->($url,
        $method eq 'POST' || $method eq 'PUT' ? $data : (),
        %$headers
    );
}

sub parse_response {
    my ($self, $resp) = @_;
    return {} if $resp->code == 204;

    $self->log($resp->content);

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

    $error_message ||= 'API call failed';
    $self->log("Error: $error_message");

    return {
        error => $error_message,
        code => $resp->code,
        content => $response_content,
    };
}

sub call {
    my ($self, $method, $path, $data) = @_;
    $self->log($path);
    $self->log($data);
    my $url = $self->build_request_url($method, $path, $data);
    my $req = $self->create_request($method, $url, $data);
    my $resp = $self->ua->request($req);
    return $self->parse_response($resp);
}

# Customer API methods
sub get_customer {
    my ($self, $customer_id) = @_;
    return $self->call('GET', "customer/$customer_id");
}

sub get_customer_by_customer_ref {
    my ($self, $customer_ref) = @_;
    my $resp = $self->call('GET', "customer", { customerRef => $customer_ref });
    return undef unless $resp && ref $resp eq 'HASH' && $resp->{Customers} && @{$resp->{Customers}};
    return $resp->{Customers}->[0]; # Customer ref is unique, so we just return the first one
}

sub create_customer {
    my ($self, $data) = @_;
    return $self->call('POST', "customer", $data);
}

# Contract (mandate) API methods
sub get_contracts {
    my ($self, $customer_id) = @_;
    my $resp = $self->call('GET', "customer/$customer_id/contract");
    return undef unless $resp && ref $resp eq 'HASH' && $resp->{Contracts} && @{$resp->{Contracts}};
    return $resp->{Contracts};
}

sub create_contract {
    my ($self, $customer_ref, $data) = @_;
    return $self->call('POST', "customer/$customer_ref/contract", $data);
}

=item archive_contract

Cancels the direct debit, writes off any outstanding arrears balance, cancels future
payments and sets the contract status to "archived".

=cut
sub archive_contract {
    my ($self, $contract_id) = @_;
    return $self->call( 'POST', "contract/$contract_id/archive", {} );
}

=item cancel_plan

Cancels a direct debit plan by archiving the contract.
Takes an args hashref that must contain either contract_id directly or
a report object that has the contract_id stored in its metadata.

Returns 1 on success or a hashref with an error key on failure.

=cut
sub cancel_plan {
    my ($self, $args) = @_;
    my $report = $args->{report};
    my $contract_id = $report->get_extra_metadata('direct_debit_contract_id');

    unless ($contract_id) {
        die "No direct debit contract ID found in report metadata";
    }

    my $resp = $self->archive_contract($contract_id);

    if (ref $resp eq 'HASH' && $resp->{error}) {
        return $resp;
    } else {
        return 1;
    }
}

=item * amend_plan

Amends the payment amount for an existing direct debit plan.

Takes a hashref of parameters:
- orig_sub - The original subscription report object containing the contract_id in metadata
- amount - The new amount to be taken (decimal number with max 2 decimal places)

=cut

sub amend_plan {
    my ($self, $args) = @_;

    my $contract_id = $args->{orig_sub}->get_extra_metadata('direct_debit_contract_id');
    unless ($contract_id) {
        die "No direct debit contract ID found in original subscription report metadata";
    }

    my $path = "contract/" . $contract_id . "/amount";
    my $data = {
        amount => $args->{amount},
        comment => "WasteWorks: Plan amount amended for " . $args->{orig_sub}->id,
    };

    my $resp = $self->call('PATCH', $path, $data);

    if (ref $resp eq 'HASH' && $resp->{error}) {
        die "Error amending plan: " . $resp->{error};
    }
}

=item * create_payment

Creates a payment for a specified contract.

=cut
sub create_payment {
    my ($self, $contract_id, $data) = @_;
    return $self->call('POST', "contract/$contract_id/payment", $data);
}

=item * one_off_payment

Adds an AdHoc payment to be taken for a specified contract.
=cut

sub one_off_payment {
    my ($self, $args) = @_;

    my $orig_sub = $args->{orig_sub};
    my $adhoc_contract_id = $orig_sub->get_extra_metadata('direct_debit_adhoc_contract_id');

    unless ($adhoc_contract_id) {
        # Adhoc contract ID not found, create a new one
        my $customer_id = $orig_sub->get_extra_metadata('direct_debit_customer_id');
        unless ($customer_id) {
            die "No direct debit customer ID found in original subscription report metadata";
        }

        # Create a new contract for the adhoc payment
        my $contract_data = {
            scheduleId => $self->config->{adhoc_schedule_id},
            start => $args->{date}->strftime('%Y-%m-%dT%H:%M:%S.000'),
            isGiftAid => 0,
            terminationType => "Until further notice",
            atTheEnd => "Switch to further notice",
        };
        my $resp = $self->create_contract($customer_id, $contract_data);

        if ( ref $resp eq 'HASH' && $resp->{error} ) {
            die 'Could not create ad hoc contract: ' . $resp->{error};
        }

        $adhoc_contract_id = $resp->{Id};
        # Store the new adhoc contract ID back in metadata for future use
        $orig_sub->set_extra_metadata('direct_debit_adhoc_contract_id', $adhoc_contract_id);
        $orig_sub->update;
    }

    # Create the adhoc payment using the determined contract ID
    my $resp = $self->create_payment($adhoc_contract_id, {
        amount => $args->{amount},
        date => $args->{date}->strftime('%Y-%m-%dT%H:%M:%S.000'),
        comment => "WasteWorks: AdHoc payment for " . $orig_sub->id,
    });

    if (ref $resp eq 'HASH' && $resp->{error}) {
        die 'Could not create ad hoc payment: ' . $resp->{error};
    } elsif (ref $resp eq 'HASH' && keys %$resp) {
        # Assuming a successful response might return some data, but 1 indicates success
        return 1;
    } elsif (ref $resp eq 'HASH' && !keys %$resp) {
        # Handle cases where success might be an empty hash {}
        return 1;
    } else {
        # Handle unexpected response format or potential success cases not returning a hash
        # Log or handle as appropriate, returning 1 for presumed success if no error indicated
        $self->log('Unexpected response format from AccessPaySuite adhoc payment: ' . Dumper($resp) );
        return 1; # Assuming success if no error hash
    }
}

sub set_callback_url {
    my ( $self, $entity, $callback ) = @_;

    my $res = $self->call(
        'POST',
        "BACS/$entity/callback",
        { url =>  "$callback" }
    );
}

1;
