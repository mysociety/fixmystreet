package FixMyStreet::Roles::CobrandPay360;

use Moo::Role;
use strict;
use warnings;
use Integrations::Echo;
use Integrations::Pay360;
with 'FixMyStreet::Roles::DDProcessor';

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

sub waste_get_sub_quantity {
    my ($self, $service) = @_;

    my $quantity = 0;
    my $tasks = Integrations::Echo::force_arrayref($service->{Data}, 'ExtensibleDatum');
    return 0 unless scalar @$tasks;
    for my $data ( @$tasks ) {
        next unless $data->{DatatypeName} eq 'LBB - GW Container';
        my $kids = Integrations::Echo::force_arrayref($data->{ChildData}, 'ExtensibleDatum');
        for my $child ( @$kids ) {
            next unless $child->{DatatypeName} eq 'Quantity';
            $quantity = $child->{Value}
        }
    }

    return $quantity;
}

1;
