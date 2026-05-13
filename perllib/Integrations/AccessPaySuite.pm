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
    my ($self, $method, $path, $data, $no_log) = @_;
    $self->log($path);
    $self->log($data) unless $no_log;
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
    return $self->call('POST', "customer", $data, 1);
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
Takes an args hashref that must contain:
- report: The report object containing the subscription

The method will look for a contract_id in the report's metadata. If found, it will
attempt to cancel that single contract and return any errors that occur.

If no contract_id is found in metadata, the caller can optionally provide an arrayref
of contract IDs to try via the contract_ids parameter:

    $integration->cancel_plan({
        report => $report,
        contract_ids => ['CONTRACT-1', 'CONTRACT-2'],
    });

If multiple contract IDs are provided via contract_ids, the method will attempt to
cancel all of them, ignoring any errors (useful for legacy scenarios where we may
not know which contract is the correct one).

Returns 1 on success, or a hashref with an error key on failure.

=cut
sub _record_dd_failure {
    my ($self, $report, $op, $error, $context) = @_;
    my $errors = $report->get_extra_metadata('direct_debit_errors') || {};
    my $existing = $errors->{$op} || {};
    $errors->{$op} = {
        error          => $error,
        last_failed_at => DateTime->now->set_time_zone(FixMyStreet->local_time_zone)->iso8601,
        failures       => ($existing->{failures} // 0) + 1,
        ($context ? (context => $context) : ()),
    };
    $report->set_extra_metadata(direct_debit_errors => $errors);
    $report->update;
}

sub _clear_dd_failure {
    my ($self, $report, $op) = @_;
    my $errors = $report->get_extra_metadata('direct_debit_errors');
    return unless $errors && $errors->{$op};
    delete $errors->{$op};
    if (%$errors) {
        $report->set_extra_metadata(direct_debit_errors => $errors);
    } else {
        $report->unset_extra_metadata('direct_debit_errors');
    }
    $report->update;
}

sub cancel_plan {
    my ($self, $args) = @_;
    my $report = $args->{report};
    my $contract_id = $args->{dd_reference};

    if ($contract_id) {
        # Single contract from metadata - handle errors properly
        my $resp = $self->archive_contract($contract_id);
        if (ref $resp eq 'HASH' && $resp->{error}) {
            $self->_record_dd_failure($report, 'cancellation', $resp->{error});
            return $resp;
        } else {
            $report->set_extra_metadata(
                direct_debit_cancellation_date => DateTime->now->set_time_zone( FixMyStreet->local_time_zone )->iso8601
            );
            $report->update;
            $self->_clear_dd_failure($report, 'cancellation');
        }
        return 1;
    } elsif ($args->{contract_ids}) {
        # Multiple contract IDs for legacy scenarios - try all, ignoring errors
        for my $cid (@{$args->{contract_ids}}) {
            $self->archive_contract($cid);
        }
        return 1;
    } else {
        return { error => "No contract ID found for this subscription" };
    }
}

=item * amend_plan

Amends the payment amount for an existing direct debit plan.

Takes a hashref of parameters:
- dd_reference - The reference of the DD to amend, if known
- amount - The new amount to be taken (decimal number with max 2 decimal places)
- report - The new modification report that has been created

=cut

sub amend_plan {
    my ($self, $args) = @_;

    unless ($args->{dd_reference}) {
        $self->_record_dd_failure($args->{report}, 'amend',
            "No direct debit contract ID found in original subscription report metadata",
            { amount => $args->{amount} });
        return;
    }

    my $path = "contract/" . $args->{dd_reference} . "/amount";
    my $data = {
        amount => $args->{amount},
        comment => "WasteWorks: Plan amount amended, #" . $args->{report}->id,
    };

    my $resp = $self->call('PATCH', $path, $data);

    if (ref $resp eq 'HASH' && $resp->{error}) {
        $self->_record_dd_failure($args->{report}, 'amend', $resp->{error},
            { amount => $args->{amount} });
        return;
    }

    $self->_clear_dd_failure($args->{report}, 'amend');
    return 1;
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

    unless ($args->{dd_reference}) {
        $self->_record_dd_failure($args->{report}, 'one_off',
            "No direct debit contract ID found in original subscription report metadata",
            { amount => $args->{amount}, date => $args->{date}->iso8601 });
        return;
    }

    # Create the adhoc payment using the contract ID
    my $resp = $self->create_payment($args->{dd_reference}, {
        amount => $args->{amount},
        date => $args->{date}->strftime('%Y-%m-%dT%H:%M:%S.000'),
        comment => "WasteWorks: AdHoc payment for #" . $args->{report}->id,
    });

    if (ref $resp eq 'HASH' && $resp->{error}) {
        $self->_record_dd_failure($args->{report}, 'one_off', $resp->{error},
            { amount => $args->{amount}, date => $args->{date}->iso8601 });
        return;
    }

    $self->log('Unexpected response format from AccessPaySuite adhoc payment: ' . Dumper($resp))
        unless ref $resp eq 'HASH';
    $self->_clear_dd_failure($args->{report}, 'one_off');
    return 1;
}

1;
