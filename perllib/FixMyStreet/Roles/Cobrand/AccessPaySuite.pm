package FixMyStreet::Roles::Cobrand::AccessPaySuite;

use Moo::Role;
use Integrations::AccessPaySuite;
use DateTime;
use FixMyStreet::WorkingDays;
with 'FixMyStreet::Roles::Cobrand::DDProcessor';

sub get_config {
    return shift->feature('payment_gateway');
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

sub waste_get_next_dd_day {
    my ($self, $payment_type) = @_;

    # new DD mandates must have a 10-day wait
    my $dd_delay = 10;
    my $payment_day = 28;

    my $dt = DateTime->now->set_time_zone( FixMyStreet->local_time_zone );
    my $wd = FixMyStreet::WorkingDays->new(
        public_holidays => FixMyStreet::Cobrand::UK::public_holidays()
    );

    my $payment_date = $wd->add_days( $dt, $dd_delay );

    # Find the next '28th'.
    # If date is greater than 28, we need to move into next month.
    if ( $payment_date->day > $payment_day ) {
        # Set day first, because if e.g. we are on the 31st of Jan,
        # adding one month will push us into March, when we want to be in Feb.
        $payment_date->set_day($payment_day);
        $payment_date->add( months => 1 );
    } else {
        $payment_date->set_day($payment_day);
    }

    return $payment_date;
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
                $c->stash->{direct_debit_status} = 'pending';
            } else {
                $c->stash->{direct_debit_status} = 'active';
            }
        }
    }
}

1;
