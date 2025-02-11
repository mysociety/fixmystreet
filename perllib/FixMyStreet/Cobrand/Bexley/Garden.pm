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


    my ( $customer, $contract );

    my $results = $self->agile->CustomerSearch($uprn);

    # find the first 'ACTIVATED' Customer with an 'ACTIVE'/'PRECONTRACT' contract
    my $customers = $results->{Customers} || [];
    OUTER: for ( @$customers ) {
        next unless $_->{CustomertStatus} eq 'ACTIVATED'; # CustomertStatus (sic) options seem to be ACTIVATED/INACTIVE
        my $contracts = $_->{ServiceContracts} || [];
        next unless $contracts;
        $customer = $_;
        for ( @$contracts ) {
            next unless $_->{ServiceContractStatus} =~ /(ACTIVE|PRECONTRACT)/; # Options seem to be ACTIVE/NOACTIVE/PRECONTRACT
            $contract = $_;
            # use the first matching customer/contract
            last OUTER if $customer && $contract;
        }
    }

    return unless $customer && $contract;

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

    if ($p) {
        $self->{c}->stash->{orig_sub} = $sub->{row} = $p;
    }

    return $sub;
}

sub garden_current_subscription {
    my ($self, $services) = @_;

    my $current = $self->{c}->stash->{property}{garden_current_subscription};
    return $current if $current;

    my $uprn = $self->{c}->stash->{property}{uprn};
    return undef unless $uprn;

    my $sub = $self->lookup_subscription_for_uprn($uprn);
    return undef unless $sub;

    my $garden_due = $self->waste_sub_due( $sub->{end_date} );

    # Agile says there is a subscription; now get service data from
    # Whitespace
    my $service_ids = { map { $_->{service_id} => $_ } @$services };
    for ( @{ $self->garden_service_ids } ) {
        if ( my $srv = $service_ids->{$_} ) {
            $srv->{customer_external_ref} = $sub->{customer_external_ref};
            $srv->{end_date} = $sub->{end_date};
            $srv->{garden_bins} = $sub->{bins_count};
            $srv->{garden_cost} = $sub->{cost};
            $srv->{garden_due} = $garden_due;

            return $srv;
        }
    }

    # If we reach here then Whitespace doesn't think there's a garden service for this
    # property. If Agile does have a subscription then we need to add a service
    # to the list for this property so the frontend displays it.
    my $service = {
        agile_only => 1,
        customer_external_ref => $sub->{customer_external_ref},
        end_date => $sub->{end_date},
        garden_bins => $sub->{bins_count},
        garden_cost => $sub->{cost},
        garden_due  => $garden_due,

        uprn => $uprn,
        garden_waste => 1,
        service_description => "Garden waste",
        service_name => "Brown wheelie bin",
        service_id => "GA-240",
        schedule => "Pending",
        round_schedule => '',
        next => { pending => 1 },
    };
    push @$services, $service;
    $self->{c}->stash->{property}{garden_current_subscription} = $service;
    $self->{c}->stash->{property}{has_garden_subscription} = 1;
    return $service;
}

sub get_current_garden_bins { shift->garden_current_subscription->{garden_bins} }

sub waste_cancel_asks_staff_for_user_details { 1 }

# TODO Needs to check 14-day window after subscription started
sub waste_garden_allow_cancellation { 'all' }

sub waste_cancel_form_class {
    'FixMyStreet::App::Form::Waste::Garden::Cancel::Bexley';
}

sub waste_garden_sub_params {
    my ( $self, $data, $type ) = @_;

    my $c = $self->{c};
    my $srv = $self->garden_current_subscription;

    if ( $data->{category} eq 'Cancel Garden Subscription' ) {
        my $parser = DateTime::Format::Strptime->new( pattern => '%d/%m/%Y' );
        my $due_date_str = $parser->format_datetime( DateTime->now->add(days => 1) );

        my $reason = $data->{reason};
        $reason .= ': ' . $data->{reason_further_details}
            if $data->{reason_further_details};

        $c->set_param( 'customer_external_ref', $srv->{customer_external_ref} );
        $c->set_param( 'due_date', $due_date_str );
        $c->set_param( 'reason', $reason );

    } elsif ( $data->{title} =~ /Renew/ ) {
        $c->set_param( 'type', 'renew' );
        $c->set_param( 'customer_external_ref', $srv->{customer_external_ref} );
        $c->set_param( 'total_containers', $data->{bins_wanted} );

    } elsif ( $data->{category} eq 'Garden Subscription' ) {
        $c->set_param( 'total_containers', $data->{bins_wanted} );

    }
}

sub garden_due_days { 42 }

=head2 waste_sub_due

Returns true/false if now is less than garden_due_days before DATE.

=cut

sub waste_sub_due {
    my ( $self, $date ) = @_;

    my $now = DateTime->now->set_time_zone( FixMyStreet->local_time_zone );
    my $sub_end = DateTime::Format::W3CDTF->parse_datetime($date);

    my $diff = $now->delta_days($sub_end)->in_units('days');
    return $diff <= $self->garden_due_days;
}

=head2 waste_sub_overdue

Returns true/false if now is past DATE.

=cut

sub waste_sub_overdue {
    my ( $self, $date ) = @_;

    my $now = DateTime->now->set_time_zone( FixMyStreet->local_time_zone )
        ->truncate( to => 'day' );
    my $sub_end = DateTime::Format::W3CDTF->parse_datetime($date)
        ->truncate( to => 'day' );

    return $now > $sub_end;
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

1;
