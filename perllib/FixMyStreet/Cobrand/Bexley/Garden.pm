=head1 NAME

FixMyStreet::Cobrand::Bexley::Garden - code specific to Bexley WasteWorks GGW

=cut

package FixMyStreet::Cobrand::Bexley::Garden;

use Moo::Role;

sub garden_service_name { 'garden waste collection service' }

# TODO No current subscription look up here
#
sub garden_current_subscription { }

=item * You can order a maximum of five bins

=cut

sub waste_garden_maximum { 5 }

=item * Garden waste has different price for the first bin

=cut

sub garden_waste_cost_pa {
    my ($self, $bin_count) = @_;
    $bin_count ||= 1;
    my $per_bin_cost = $self->garden_waste_subsequent_cost_pa;
    my $first_cost = $self->garden_waste_first_cost_pa;
    my $cost = $per_bin_cost * ($bin_count-1) + $first_cost;
    return $cost;
}

sub garden_waste_first_cost_pa { $_[0]->_get_cost('ggw_cost_first_cc') } # XXX DD
sub garden_waste_subsequent_cost_pa { $_[0]->_get_cost('ggw_cost_other') }

1;
