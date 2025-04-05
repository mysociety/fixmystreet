package FixMyStreet::Roles::Cobrand::Bottomline;

use Moo::Role;
use Integrations::Bottomline;
with 'FixMyStreet::Roles::Cobrand::DDProcessor';

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
    default => 'SUCCESS',
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
    $new_sub->set_extra_metadata('dd_mandate_id', $payment->data->{mandateId});
    $new_sub->set_extra_metadata('dd_instruction_id', $payment->data->{instructionId});

    my $contact = $self->get_dd_integration->get_contact_from_email($new_sub->user->email);
    if ($contact) {
        $new_sub->set_extra_metadata('dd_contact_id', $contact->{id});
    }
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

1;
