=head1 NAME

FixMyStreet::Cobrand::Bexley::Garden - code specific to Bexley WasteWorks GGW

=cut

package FixMyStreet::Cobrand::Bexley::Garden;

use Integrations::Agile;

use Moo::Role;
with 'FixMyStreet::Roles::Cobrand::SCP',
     'FixMyStreet::Roles::Cobrand::Paye';

has agile => (
    is => 'lazy',
# TODO url to config
    default => sub { Integrations::Agile->new( url => 'https://integration.stg.agileapplications.co.uk/api/bexley/gardenwaste/external/request' ) },
);

sub garden_service_name { 'garden waste collection service' }

sub garden_service_ids {
    return [ 'GA-140', 'GA-240' ];
}

sub garden_current_subscription {
    my $self = shift;

    my $uprn = $self->{c}->stash->{property}{uprn};
    return undef unless $uprn;

    my $is_free = $self->agile->IsAddressFree($uprn);
    return undef if $is_free->{IsFree} eq 'True';

    # Agile says there is a subscription; now get service data from
    # Whitespace
    my $services = $self->{c}->stash->{services};
    map { my $srv = $services->{$_}; return $srv if $srv }
        @{ $self->garden_service_ids };

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
