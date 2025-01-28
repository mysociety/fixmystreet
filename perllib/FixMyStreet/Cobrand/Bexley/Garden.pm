=head1 NAME

FixMyStreet::Cobrand::Bexley::Garden - code specific to Bexley WasteWorks GGW

=cut

package FixMyStreet::Cobrand::Bexley::Garden;

use DateTime::Format::Strptime;

use Integrations::Agile;

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
    my $self = shift;

    my $uprn = $self->{c}->stash->{property}{uprn};
    return undef unless $uprn;

    my $results = $self->agile->CustomerSearch($uprn);
    ::Dwarn($results);
    return undef unless $results && $results->{Customers};
    my $customer = $results->{Customers}[0];
    return undef unless $customer && $customer->{ServiceContracts};
    my $contract = $results->{ServiceContracts}[0];
    return unless $contract;

    # Agile says there is a subscription; now get service data from
    # Whitespace
    my $services = $self->{c}->stash->{services};
    for my $id (@{ $self->garden_service_ids }) {
        ::Dwarn($id);
        if (my $srv = $services->{$id}) {
            ::Dwarn($srv);
            $srv->{garden_bins} = $contract->{WasteContainerQuantity};
            $srv->{end_date} = DateTime::Format::Strptime->new(pattern => '%d/%m/%Y %H:%M')->parse_datetime($contract->{EndDate});
            ::Dwarn($srv);
            return $srv;
        }
    }

    return { agile_only => 1 };
}

# TODO This is a placeholder
sub get_current_garden_bins { 1 }

sub waste_cancel_asks_staff_for_user_details { 1 }

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
