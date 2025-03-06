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

1;
