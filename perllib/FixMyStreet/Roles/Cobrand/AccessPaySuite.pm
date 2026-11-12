package FixMyStreet::Roles::Cobrand::AccessPaySuite;

use Moo::Role;
use Integrations::AccessPaySuite;
use DateTime;
use DateTime::Format::W3CDTF;
use FixMyStreet::WorkingDays;
with 'FixMyStreet::Roles::Cobrand::DDProcessor';

has paymentDateField => ( is => 'ro', default => 'DateOfCollection' ); # CollectionDate might be weekend
has paymentTypeField => ( is => 'ro', default => 'Type' );
has paymentInPence => ( is => 'ro', default => 1 );
has oneOffReferenceField => ( is => 'ro', default => 'Comment' );
has referenceField => ( is => 'ro', default => 'DirectDebitReference' );
has statusField => ( is => 'ro', default => 'Status' );
has paymentTakenCode => ( is => 'ro', default => 'Paid' );
#has cancelReferenceField => ( is => 'ro', default => 'Reference' );
#has cancelledDateField => ( is => 'ro', default => 'CancelledDate' );

sub parse_payment_date {
    my ($self, $date) = @_;
    return DateTime::Format::W3CDTF->parse_datetime($date);
}

sub get_config {
    return shift->feature('payment_gateway');
}

sub add_new_sub_metadata {
    my ($self, $new_sub, $payment) = @_;
    $new_sub->set_extra_metadata('direct_debit_contract_id', $payment->data->{ContractId})
        unless $new_sub->get_extra_metadata('direct_debit_contract_id');
    $new_sub->set_extra_metadata('direct_debit_customer_id', $payment->data->{CustomerId})
        unless $new_sub->get_extra_metadata('direct_debit_customer_id');
}

sub get_dd_integration {
    my ($self) = @_;

    my $config = $self->get_config;

    return Integrations::AccessPaySuite->new({
        config => {
            endpoint => $config->{dd_endpoint},
            api_key => $config->{dd_api_key},
            client_code => $config->{dd_client_code},
            log_ident => $config->{log_ident},
        },
    });
}

sub waste_payment_type {
    my ($self, $type, $ref) = @_;

    my $category = 'Garden Subscription';
    my $sub_type;
    if ( $type eq 'First Time' ) {
        $sub_type = $self->waste_subscription_types->{New};
    } elsif ( $type eq 'Regular' ) {
        if ( $ref ) {
            $sub_type = $self->waste_subscription_types->{Amend};
        } else {
            $sub_type = $self->waste_subscription_types->{Renew};
        }
    }

    return ($category, $sub_type);
}

sub waste_get_next_dd_day {
    my ($self, $payment_type) = @_;

    # new DD mandates must have a 10-day wait
    my $dd_delay = 10;

    # ad-hoc payments on an existing mandate only need a 5-day wait
    if ($payment_type && ($payment_type eq 'ad-hoc')) { $dd_delay = 5; }

    my $dt = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);
    my $wd = FixMyStreet::WorkingDays->new(public_holidays => $self->public_holidays());

    my $next_day = $wd->add_days( $dt, $dd_delay );

    return $next_day;
}

sub waste_check_existing_dd {
    my ( $self, $p ) = @_;

    my $c = $self->{c};
    my $i = $self->get_dd_integration;

    my $customer_id = $p->get_extra_metadata('direct_debit_customer_id');

    if ($customer_id) {
        my $contracts = $i->get_contracts($customer_id);

        # TODO Order by start date descending, rather than just getting
        # the first contract? Will customer ever have more than one?

        if ($contracts && @$contracts) {
            my $contract = $contracts->[0];

            # According to
            # https://api-docs-ddcms-v3.accesspaysuite.com/#tag/Contract-Querying-and-Creation/paths/~1client~1{clientCode}~1customer~1{customerId}~1contract/post
            # contracts either have a status of 'Inactive' or 'Active'
            if ( $contract->{Status} eq 'Inactive' ) {
                my $reason = $contract->{StatusExplanation} || '';
                if ($reason =~ /BACS cancellation received|Contract and Payment Schedule cancelled|Contract archived|Contract Status updated from .*? to (Cancelled|Expired)/) {
                    $c->stash->{direct_debit_status} = 'none';
                } else {
                    $c->stash->{direct_debit_status} = 'pending';
                }
            } else {
                $c->stash->{direct_debit_status} = 'active';
            }
        }
    }
}

sub waste_report_extra_dd_data {
    my ($self) = @_;
    my $c = $self->{c};
    my $orig_sub = $c->stash->{orig_sub};

    if ($orig_sub && $orig_sub->get_extra_metadata('direct_debit_contract_id')) {
        my $report = $c->stash->{report};
        my $contract_id = $orig_sub->get_extra_metadata('direct_debit_contract_id');
        my $customer_id = $orig_sub->get_extra_metadata('direct_debit_customer_id');
        $report->set_extra_metadata(direct_debit_contract_id => $contract_id);
        $report->set_extra_metadata(direct_debit_customer_id => $customer_id);
        $report->update;
    }
}

=head2 waste_dd_get_reference

Used in garden subscription modifying, to return the contract ID to modify.

=cut

sub waste_dd_get_reference {
    my ($self) = @_;
    my $c = $self->{c};
    my $orig_sub = $c->stash->{orig_sub};
    my $contract_id = $orig_sub->get_extra_metadata('direct_debit_contract_id');
    return $contract_id;
}

1;
