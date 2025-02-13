=head1 NAME

FixMyStreet::Cobrand::Bexley::Garden - code specific to Bexley WasteWorks GGW

=cut

package FixMyStreet::Cobrand::Bexley::Garden;

use Moo::Role;
with 'FixMyStreet::Roles::Cobrand::SCP',
     'FixMyStreet::Roles::Cobrand::Paye',
     'FixMyStreet::Roles::Cobrand::AccessPaySuite';

sub garden_service_name { 'garden waste collection service' }

# TODO No current subscription look up here
#
sub garden_current_subscription { undef }

=item * You can order a maximum of five bins

=cut

sub waste_garden_maximum { 5 }

=item * Garden waste has different price for the first bin

=cut

# TODO Check
sub waste_cc_payment_sale_ref {
    my ($self, $p) = @_;
    return "GGW" . $p->get_extra_field_value('uprn');
}

sub waste_cc_payment_line_item_ref {
    my ($self, $p) = @_;
    return $p->id;
}

sub waste_payment_ref_council_code { "BEX" }

sub direct_debit_collection_method { 'internal' }

sub setup_direct_debit {
    my ($self, $form) = @_;
    my $c = $self->{c};
    my $data = $form->value;

    my $i = $self->get_dd_integration;
    my $customer = $i->create_customer({
        customerRef => $data->{email},
        email => $data->{email},
        title => $data->{name_title},
        firstName => $data->{first_name},
        surname => $data->{surname},
        postCode => $data->{post_code},
        accountNumber => $data->{account_number},
        bankSortCode => $data->{sort_code},
        accountHolderName => $data->{account_holder},
        line1 => $data->{address1},
        line2 => $data->{address2},
        line3 => $data->{address3},
        line4 => $data->{address4},
    });
    my $contract = $i->create_contract($customer->{Id}, {
        scheduleId => '38491b98-e3dd-45c1-80e7-e44941e481c6',
        start => '2025-03-01T00:00:00.000',
        isGiftAid => 0,
        terminationType => "Until further notice",
        atTheEnd => "Switch to further notice",
        paymentMonthInYear => 3,
        paymentDayInMonth => 28,
        amount => 50.00,
        additionalReference => 'BEXLEY GGW',
    });

    ::Dwarn($data);
    ::Dwarn($customer);
    ::Dwarn($contract);
    return 1;
}

1;
