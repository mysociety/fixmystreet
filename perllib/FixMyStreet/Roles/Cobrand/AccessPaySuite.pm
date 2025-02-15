package FixMyStreet::Roles::Cobrand::AccessPaySuite;

use Moo::Role;
use Integrations::AccessPaySuite;
use DateTime;
use FixMyStreet::WorkingDays;
with 'FixMyStreet::Roles::Cobrand::DDProcessor';

sub get_config {
    return shift->feature('payment_gateway');
}

# Save metadata about the DD payment that will be useful later
sub add_new_sub_metadata {
    my ($self, $new_sub, $payment) = @_;

    # TODO: Store any necessary metadata from the payment response
    # that will be needed for future operations
    $new_sub->set_extra_metadata('dd_mandate_id', $payment->data->{mandateId});
    $new_sub->set_extra_metadata('dd_payer_id', $payment->data->{payerId});
}

sub get_dd_integration {
    my ($self) = @_;

    my $config = $self->get_config;

    return Integrations::AccessPaySuite->new({
        config => {
            endpoint => $config->{dd_endpoint},
            api_key => $config->{dd_api_key},
            client_code => $config->{dd_client_code},
        },
    });
}

# TODO: Is this correct?
sub waste_get_next_dd_day {
    my ($self, $payment_type) = @_;

    # new DD mandates must have a 10-day wait
    my $dd_delay = 10;

    my $dt = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);
    my $wd = FixMyStreet::WorkingDays->new(public_holidays => FixMyStreet::Cobrand::UK::public_holidays());

    my $next_day = $wd->add_days( $dt, $dd_delay );

    return $next_day;
}

1;
