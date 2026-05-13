package FixMyStreet::Roles::Cobrand::Pay360;

use Moo::Role;
use strict;
use warnings;
use Integrations::Echo;
use Integrations::Pay360;
with 'FixMyStreet::Roles::Cobrand::DDProcessor';

has paymentDateField => (
    is => 'ro',
    default => 'DueDate',
);

has paymentTypeField => (
    is => 'ro',
    default => 'Type',
);

has oneOffReferenceField => (
    is => 'ro',
    default => 'YourRef',
);

has referenceField => (
    is => 'ro',
    default => 'PayerReference',
);

has cancelReferenceField => (
    is => 'ro',
    default => 'Reference',
);

has statusField => (
    is => 'ro',
    default => 'Status',
);

has paymentTakenCode => (
    is => 'ro',
    default => 'Paid',
);

has cancelledDateField => (
    is => 'ro',
    default => 'CancelledDate',
);

sub get_config {
    return shift->feature('payment_gateway');
}

sub get_dd_integration {
    my $self = shift;
    my $config = $self->feature('payment_gateway');
    my $i = Integrations::Pay360->new({
        config => $config
    });

    return $i;
}

sub waste_payment_type {
    my ($self, $type, $ref) = @_;

    my ($sub_type, $category);
    if ( $type eq 'Payment: 01' || $type eq 'First Time' ) {
        $category = 'Garden Subscription';
        $sub_type = $self->waste_subscription_types->{New};
    } elsif ( $type eq 'Payment: 17' || $type eq 'Regular' ) {
        $category = 'Garden Subscription';
        if ( $ref ) {
            $sub_type = $self->waste_subscription_types->{Amend};
        } else {
            $sub_type = $self->waste_subscription_types->{Renew};
        }
    }

    return ($category, $sub_type);
}

sub waste_check_existing_dd {
    my ($self, $p) = @_;
    my $c = $self->{c};

    my $payer_reference = $p->get_extra_metadata('payerReference');
    if (!$payer_reference) {
        my $code = $self->waste_payment_ref_council_code;
        my $uprn = $p->uprn || '';
        my $id = $p->id;
        $payer_reference = substr($code . '-' . $id . '-' . $uprn, 0, 18);
    }

    my $i = $self->get_dd_integration;
    my $dd_status = $i->get_payer({ payer_reference => $payer_reference }) || '';

    if ($dd_status eq 'Creation Pending') {
        $c->stash->{direct_debit_status} = 'pending';
        $c->stash->{pending_subscription} = $p;
    } elsif ($dd_status eq 'Active') {
        $c->stash->{direct_debit_status} = 'active';
    } else {
        $c->stash->{direct_debit_status} = 'none';
    }
}

sub waste_report_extra_dd_data {
    my ($self) = @_;
    my $c = $self->{c};
    my $orig_sub = $c->stash->{orig_sub};

    if ($orig_sub) {
        my $report = $c->stash->{report};
        my $ref = $orig_sub->get_extra_metadata('payerReference');
        $report->set_extra_metadata(payerReference => $ref) if $ref;
        $report->update;
    }
}

=head2 waste_dd_get_reference

Used in garden subscription amendment, returns the payerReference
stored on the original subscription report.

=cut

sub waste_dd_get_reference {
    my ($self) = @_;
    my $c = $self->{c};
    my $orig_sub = $c->stash->{orig_sub};
    return $orig_sub->get_extra_metadata('payerReference');
}

1;
