package FixMyStreet::Roles::Bottomline;

use Moo::Role;
use strict;
use warnings;
use Integrations::Bottomline;
with 'FixMyStreet::Roles::DDProcessor';

has paymentDateField => (
    is => 'ro',
    default => 'paymentDate',
);

has paymentTypeField => (
    is => 'ro',
    default => 'transactionCode',
);

has oneOffReferenceField => (
    is => 'ro',
    default => 'comments',
);

has referenceField => (
    is => 'ro',
    default => 'reference',
);

has statusField => (
    is => 'ro',
    default => 'status',
);

has paymentTakenCode => (
    is => 'ro',
    default => '', # Would be SUCCESS in live
);

# XXX
has cancelledDateField => (
    is => 'ro',
    default => 'lastUpdated',
);

has cancelReferenceField => (
    is => 'ro',
    default => 'reference',
);

sub get_config {
    return shift->feature('bottomline');
}

# save some data about the DD payment that will be useful later for updating
# the mandate
sub add_new_sub_metadata {
    my ($self, $new_sub, $payment) = @_;

    $new_sub->set_extra_metadata('dd_profile_id', $payment->data->{profileId});
    $new_sub->set_extra_metadata('dd_instruction_id', $payment->data->{instructionId});
}

sub get_dd_integration {
    my $self = shift;
    my $config = $self->feature('bottomline');
    my $i = Integrations::Bottomline->new({
        config => $config
    });

    return $i;
}

sub waste_payment_type {
    my ($self, $type, $ref) = @_;

    my ($sub_type, $category);
    if ( $type eq '01' ) {
        $category = 'Garden Subscription';
        $sub_type = $self->waste_subscription_types->{New};
    } elsif ( $type eq 17 ) {
        $category = 'Garden Subscription';
        # XXX
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
        my $uprn = $p->get_extra_field_value('uprn') || '';
        my $id = $p->id;
        $payer_reference = substr($code . '-' . $id . '-' . $uprn, 0, 18);
    }

    my $i = $self->get_dd_integration;
    my $mandate = $i->get_mandate_from_reference($payer_reference) || {};
    my $dd_status = $mandate->{status} || '';
    $c->stash->{direct_debit_mandate} = $mandate;

    if ($dd_status eq 'DRAFT') {
        $c->stash->{direct_debit_status} = 'pending';
        $c->stash->{pending_subscription} = $p;
    } elsif ($dd_status eq 'ACTIVE') {
        $c->stash->{direct_debit_status} = 'active';
    } else {
        $c->stash->{direct_debit_status} = 'none';
    }
}

sub waste_dd_paid_date {
    my ($self, $date) = @_;
    my ($year, $month, $day) = ( $date =~ m#^(\d+)-(\d+)-(\d+)#);
    return ($day, $month, $year);
}

1;
