=head1 NAME

FixMyStreet::Cobrand::Bexley::Garden - code specific to Bexley WasteWorks GGW

=cut

package FixMyStreet::Cobrand::Bexley::Garden;

use DateTime::Format::Strptime;
use Integrations::Agile;
use FixMyStreet::App::Form::Waste::Garden::Cancel::Bexley;
use Try::Tiny;

use Moo::Role;
with 'FixMyStreet::Roles::Cobrand::SCP',
     'FixMyStreet::Roles::Cobrand::Paye';

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

sub garden_current_subscription {
    my ($self, $services) = @_;

    my $current = $self->{c}->stash->{property}{garden_current_subscription};
    return $current if $current;

    my $uprn = $self->{c}->stash->{property}{uprn};
    return undef unless $uprn;

# TODO Fetch active subscription from DB for UPRN
#      (get_original_sub() in Controller/Waste.pm needs to handle Bexley UPRN).
#      Could be more than one customer, so match against email.
#      Could be more than one contract, so match against reference.

    my $results = $self->agile->CustomerSearch($uprn);
    return undef unless $results && $results->{Customers};
    my $customer = $results->{Customers}[0];
    return undef unless $customer && $customer->{ServiceContracts};
    my $contract = $customer->{ServiceContracts}[0];
    return unless $contract;
    # XXX should maybe sort by CreatedDate rather than assuming first is OK
    my $cost = try {
        my ($payment) = grep { $_->{PaymentStatus} eq 'Paid' } @{ $contract->{Payments} };
        return $payment->{Amount};
    };

    my $parser
        = DateTime::Format::Strptime->new( pattern => '%d/%m/%Y %H:%M' );
    my $end_date = $parser->parse_datetime( $contract->{EndDate} );

    # Agile says there is a subscription; now get service data from
    # Whitespace
    # XXX For performance, should we only query Agile if there's a matching Whitespace service?
    my $service_ids = { map { $_->{service_id} => $_ } @$services };
    for ( @{ $self->garden_service_ids } ) {
        if ( my $srv = $service_ids->{$_} ) {
            $srv->{customer_external_ref}
                = $customer->{CustomerExternalReference};
            $srv->{end_date} = $end_date;
            $srv->{garden_bins} = $contract->{WasteContainerQuantity};
            $srv->{garden_cost} = $cost;
            return $srv;
        }
    }

    return {
        agile_only => 1,
        customer_external_ref => $customer->{CustomerExternalReference},
        end_date => $end_date,
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
        my $due_date_str = $parser->format_datetime( $srv->{end_date} );

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

1;
