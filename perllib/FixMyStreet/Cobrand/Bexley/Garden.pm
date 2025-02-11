=head1 NAME

FixMyStreet::Cobrand::Bexley::Garden - code specific to Bexley WasteWorks GGW

=cut

package FixMyStreet::Cobrand::Bexley::Garden;

use DateTime::Format::Strptime;
use Integrations::Agile;
use FixMyStreet::App::Form::Waste::Garden::Cancel::Bexley;
use Try::Tiny;
use JSON::MaybeXS;

use Moo::Role;
with 'FixMyStreet::Roles::Cobrand::SCP',
     'FixMyStreet::Roles::Cobrand::Paye',
     'FixMyStreet::Roles::Cobrand::AccessPaySuite';

use FixMyStreet::App::Form::Waste::Garden::Bexley;

has agile => (
    is => 'lazy',
    default => sub {
        my $self = shift;
        my $cfg = $self->feature('agile');
        return Integrations::Agile->new(%$cfg);
    },
);

sub garden_service_name { 'garden waste collection service' }

sub garden_service_ids {
    return [ 'GA-140', 'GA-240' ];
}

sub lookup_subscription_for_uprn {
    my ($self, $uprn) = @_;

    my $sub = {
        row => undef,

        email => undef,
        cost => undef,
        end_date => undef,
        customer_external_ref => undef,
        bins_count => undef,
    };


    my $results = $self->agile->CustomerSearch($uprn);
    return undef unless $results && $results->{Customers};
    my $customer = $results->{Customers}[0];
    return undef unless $customer && $customer->{ServiceContracts};
    my $contract = $customer->{ServiceContracts}[0];
    return unless $contract;

    # XXX should maybe sort by CreatedDate rather than assuming first is OK
    $sub->{cost} = try {
        my ($payment) = grep { $_->{PaymentStatus} eq 'Paid' } @{ $contract->{Payments} };
        return $payment->{Amount};
    };

    my $parser = DateTime::Format::Strptime->new( pattern => '%d/%m/%Y %H:%M' );
    $sub->{end_date} = $parser->parse_datetime( $contract->{EndDate} );

    $sub->{customer_external_ref} = $customer->{CustomerExternalReference};

    $sub->{bins_count} = $contract->{WasteContainerQuantity};

    my $c = $self->{c};
    my $p = $c->model('DB::Problem')->search({
        category => 'Garden Subscription',
        extra => { '@>' => encode_json({ "_fields" => [ { name => "uprn", value => $uprn } ] }) },
        state => { '!=' => 'hidden' },
        external_id => "Agile-" . $contract->{Reference},
    })->order_by('-id')->to_body($c->cobrand->body)->first;

    $sub->{row} = $p if $p;

    return $sub;
}

sub garden_current_subscription {
    my ($self, $services) = @_;

    my $current = $self->{c}->stash->{property}{garden_current_subscription};
    return $current if $current;

    my $uprn = $self->{c}->stash->{property}{uprn};
    return undef unless $uprn;

    # Agile says there is a subscription; now get service data from
    # Whitespace
    my $service_ids = { map { $_->{service_id} => $_ } @$services };
    for ( @{ $self->garden_service_ids } ) {
        if ( my $srv = $service_ids->{$_} ) {
            my $sub = $self->lookup_subscription_for_uprn($uprn);
            $srv->{customer_external_ref} = $sub->{customer_external_ref};
            $srv->{end_date} = $sub->{end_date};
            $srv->{garden_bins} = $sub->{bins_count};
            $srv->{garden_cost} = $sub->{cost};
            $self->{c}->stash->{orig_sub} = $sub->{row};
            return $srv;
        }
    }

    my $sub = $self->lookup_subscription_for_uprn($uprn);
    return {
        agile_only => 1,
        customer_external_ref => $sub->{customer_external_ref},
        end_date => $sub->{end_date},
    };
}

# TODO This is a placeholder
sub get_current_garden_bins { 1 }

sub waste_cancel_asks_staff_for_user_details { 1 }

# TODO Needs to check 14-day window after subscription started
sub waste_garden_allow_cancellation { 'all' }

sub waste_cancel_form_class {
    'FixMyStreet::App::Form::Waste::Garden::Cancel::Bexley';
}

sub waste_garden_sub_params {
    my ( $self, $data, $type ) = @_;

    my $c = $self->{c};

    if ( $data->{category} eq 'Cancel Garden Subscription' ) {
        my $srv = $self->garden_current_subscription;

        my $parser = DateTime::Format::Strptime->new( pattern => '%d/%m/%Y' );
        my $due_date_str = $parser->format_datetime( DateTime->now->add(days => 1) );

        my $reason = $data->{reason};
        $reason .= ': ' . $data->{reason_further_details}
            if $data->{reason_further_details};

        $c->set_param( 'customer_external_ref', $srv->{customer_external_ref} );
        $c->set_param( 'due_date', $due_date_str );
        $c->set_param( 'reason', $reason );
    }
}

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

sub waste_setup_direct_debit {
    my ($self) = @_;
    my $c = $self->{c};

    my $report = $c->stash->{report};
    my $email = $report->user->email;

    my $data = $c->stash->{form_data};

    # Lookup existing customer and contract
    my $i = $self->get_dd_integration;
    my $customer = $i->get_customer_by_customer_ref($email);

    if (!$customer) {
        my $customer_data = {
            customerRef => $email, # Use email as customer reference
            email => $email,
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
        };
        $customer = $i->create_customer($customer_data);
    } else {
        # XXX do we need to check that the existing customer's details (name/address/bank/etc)
        # match what they've provided to us? If they don't match, what should we do?
    }

    my $contract_data = {
        scheduleId => $c->stash->{payment_details}->{dd_schedule_id},
        start => $c->stash->{payment_date}->strftime('%Y-%m-%dT%H:%M:%S.000'),
        isGiftAid => 0,
        terminationType => "Until further notice",
        atTheEnd => "Switch to further notice",
        paymentMonthInYear => $c->stash->{payment_date}->month,
        paymentDayInMonth => 28, # Always the 28th for Bexley
        amount => $c->stash->{amount},
        additionalReference => $c->stash->{reference},
    };

    if ($customer->{error}) {
        $c->stash->{error} = $customer->{error};
        return 0;
    }

    my $contract = $i->create_contract($customer->{Id}, $contract_data);

    if ($contract->{error}) {
        $c->stash->{error} = $contract->{error};
        return 0;
    }

    # Store the customer and contract IDs for future reference
    $report->set_extra_metadata('direct_debit_customer_id', $customer->{Id});
    $report->set_extra_metadata('direct_debit_contract_id', $contract->{Id});
    $report->set_extra_metadata('direct_debit_reference', $contract->{DirectDebitRef});
    $report->confirm;

    # To send to Agile
    my $parser = DateTime::Format::Strptime->new( pattern => '%d/%m/%Y' );
    my $start_date_str
        = $parser->format_datetime( $c->stash->{payment_date} );
    $report->update_extra_field(
        {   name  => 'direct_debit_reference',
            value => $contract->{DirectDebitRef},
        }
    );
    $report->update_extra_field(
        {   name  => 'direct_debit_start_date',
            value => $start_date_str,
        }
    );

    $report->update;

    return 1;
}

sub waste_garden_subscribe_form_setup {
    my ($self) = @_;

    # Use a custom form class that includes fields for bank details
    $self->{c}->stash->{form_class} = 'FixMyStreet::App::Form::Waste::Garden::Bexley';
}

=head2 * garden_waste_first_bin_discount_applies

The cost of the first garden waste bin is discounted if the payment method
is direct debit.

=cut

sub garden_waste_first_bin_discount_applies {
    my ($self, $data) = @_;
    return $data->{payment_method} && $data->{payment_method} eq 'direct_debit';
}

sub waste_staff_choose_payment_method { 1 }

1;
