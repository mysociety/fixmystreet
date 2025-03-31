package WasteWorks::Costs;

use Moo;
use Types::Standard qw(Bool Enum);

has cobrand => ( is => 'ro' ); # Cobrand we're working with, to get actual data
has discount => ( is => 'rw', isa => Bool ); # If a discount is applied (Brent only)
has first_bin_discount => ( is => 'rw', isa => Bool ); # If a discount should be applied to the first bin

has service => ( is => 'lazy' ); # Existing garden service (for the end date)
has payments => ( is => 'lazy' );
has discount_amount => ( is => 'lazy' );
has first_bin_discount_absolute_amount => ( is => 'lazy' );
has renewal_type => ( is => 'lazy', isa => Enum['current', 'subscription_end'] );
has has_pro_rata_modify => ( is => 'lazy', isa => Bool );

# $_[0] is the self instance, just without setting a variable
# All the stuff reliant on the cobrand is worked out here

sub _build_service { $_[0]->cobrand->garden_current_subscription }

sub _build_payments { $_[0]->cobrand->feature('payment_gateway') }

sub _build_discount_amount {
    my $features = $_[0]->cobrand->feature('waste_features') || {};
    return $features->{ggw_discount_as_percent};
}

sub _build_first_bin_discount_absolute_amount {
    my $features = $_[0]->cobrand->feature('payment_gateway') || {};
    return $features->{ggw_first_bin_discount} // 0;
}

sub _build_renewal_type {
    return 'subscription_end' if $_[0]->cobrand->moniker eq 'kingston' || $_[0]->cobrand->moniker eq 'bromley';
    return 'current';
}

sub _build_has_pro_rata_modify { $_[0]->cobrand->moniker eq 'bromley' }

# Now the code that uses the data to work out costs

sub bins {
    my ( $self, $count, $type ) = @_;
    $count ||= 1;
    my $per_bin = $self->get_cost('ggw_cost') ;
    my $first_cost;
    if ( ( $type // '' ) eq 'modify' ) {
        # Ignore any 'first bin' costs/discounts for subscription modification
        $first_cost = $per_bin;
    } else {
        $first_cost = $self->get_cost('ggw_cost_first') || $per_bin;
        if ($self->first_bin_discount) {
            $first_cost -= $self->first_bin_discount_absolute_amount;
        }
    }
    my $cost = $self->_first_diff_calc($first_cost, $per_bin, $count);
    return $cost;
}

sub sacks {
    my ($self, $count) = @_;
    my $cost = $self->get_cost('ggw_sacks_cost');
    return $self->bins($count) if !$cost;
    $cost *= $count;
    return $self->apply_garden_discount($cost);
}

sub _renewal {
    my ($self, $type, $count, $end_date) = @_;
    my $prefix = $type eq 'sacks' ? 'ggw_sacks_cost' : 'ggw_cost';
    if ($self->renewal_type eq 'subscription_end') {
        $end_date //= $self->service->{end_date};
        my $cost = $self->get_cost($prefix . '_renewal', $end_date)
            || $self->get_cost($prefix, $end_date);
        my $first_cost = $self->get_cost($prefix . '_renewal_first', $end_date)
            || $self->get_cost($prefix . '_first', $end_date)
            || $cost;
        if ($self->first_bin_discount) {
            $first_cost -= $self->first_bin_discount_absolute_amount;
        }
        $cost = $self->_first_diff_calc($first_cost, $cost, $count);
        return $cost;
    } elsif ($type eq 'sacks') {
        return $self->sacks($count);
    } else {
        return $self->bins($count);
    }
}

sub bins_renewal {
    my $self = shift;
    return $self->_renewal('bins', @_);
}

sub sacks_renewal {
    my $self = shift;
    return $self->_renewal('sacks', @_);
}

sub new_bin_admin_fee {
    my ($self, $count) = @_;

    my $per_new_bin_first_cost = $self->get_cost('ggw_new_bin_first_cost');
    return 0 unless $per_new_bin_first_cost;

    $count ||= 0;
    my $per_new_bin_cost = $self->get_cost('ggw_new_bin_cost');
    my $cost = $self->_first_diff_calc($per_new_bin_first_cost, $per_new_bin_cost, $count);
    return $cost;
}

sub _first_diff_calc {
    my ($self, $first_cost, $rest_cost, $count) = @_;
    my $cost = 0;
    if ($count > 0) {
        $cost += $first_cost;
        if ($count > 1) {
            $cost += $rest_cost * ($count - 1);
        }
    }
    return $self->apply_garden_discount($cost);
}

# If modifying and adding a new bin, how much do they cost
sub pro_rata_cost {
    my ($self, $count) = @_;
    if ($self->has_pro_rata_modify) {
        my $end_date = $self->service->{end_date};
        my $now = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);
        my $sub_end = DateTime::Format::W3CDTF->parse_datetime($end_date);
        my $cost = $count * $self->get_pro_rata_bin_cost( $sub_end, $now );
        return $self->apply_garden_discount($cost);
    } else {
        return $self->bins( $count, 'modify' );
    }
}

sub get_pro_rata_bin_cost {
    my ($self, $end, $start) = @_;

    my $weeks = $end->delta_days($start)->in_units('weeks');
    $weeks -= 1 if $weeks > 0;

    my $base = $self->get_cost('pro_rata_minimum', $start);
    my $weekly_cost = $self->get_cost('pro_rata_weekly', $start);
    my $cost = sprintf "%.0f", ($base + ( $weeks * $weekly_cost ));

    return $cost;
}

sub apply_garden_discount {
    my ($self, $charge ) = @_;
    return $charge unless $self->discount;
    my $discount = $self->discount_amount;
    my $proportion_to_pay = 1 - $discount / 100;
    my $discounted = $charge ? $charge * $proportion_to_pay : $charge;
    return $discounted;
}

# Next month does not currently handle a first bin being a different price, if
# those two ever get used together.

sub next_month {
    my $self = shift;
    my $per_bin = $self->get_cost('ggw_cost');
    $self->garden_cost_pa_in_one_month($per_bin);
}

=head2 garden_cost_pa_in_one_month

Returns the cost of garden waste in one month, if it differs from the usual
cost passed in. This is to show an upcoming price change on the garden
subscription intro page.

=cut

sub garden_cost_pa_in_one_month {
    my ($self, $cost_pa) = @_;

    my $costs = $self->payments or return;
    $costs = $costs->{ggw_cost};
    return unless ref $costs eq 'ARRAY';

    my $pattern = '%Y-%m-%d %H:%M';
    my $date = DateTime->now->set_time_zone(FixMyStreet->local_time_zone)->add(months => 1);
    $date = $date->strftime($pattern);

    my @sorted = sort { $b->{start_date} cmp $a->{start_date} } @$costs;
    foreach my $cost (@sorted) {
        if ($cost->{start_date} le $date) {
            my $parser = DateTime::Format::Strptime->new(pattern => $pattern);
            return {
                cost => $cost->{cost},
                start_date => $parser->parse_datetime($cost->{start_date}),
            } if $cost->{cost} != $cost_pa;
            return;
        }
    }

    die("Couldn't find a valid cost item");
}

# Functions used for display of bin pricing/calculation during flow (all begin per_)
# $_[0] is the self instance, just without setting a variable

sub per_bin {
    $_[0]->apply_garden_discount($_[0]->get_cost('ggw_cost'));
}
sub per_bin_first {
    $_[0]->apply_garden_discount(
        $_[0]->get_cost('ggw_cost_first')
        || $_[0]->get_cost('ggw_cost')
    );
}

sub per_sack { $_[0]->sacks(1) }

sub per_new_bin_first {
    $_[0]->apply_garden_discount($_[0]->get_cost('ggw_new_bin_first_cost'));
}
sub per_new_bin {
    $_[0]->apply_garden_discount($_[0]->get_cost('ggw_new_bin_cost'));
}

sub per_bin_renewal {
    my $self = shift;
    my $end_date;
    $end_date = $self->service->{end_date} if $self->renewal_type eq 'subscription_end';
    my $cost = $self->get_cost('ggw_cost_renewal', $end_date)
        || $self->get_cost('ggw_cost', $end_date);
    return $self->apply_garden_discount($cost);
}
sub per_bin_renewal_first {
    my $self = shift;
    my $end_date;
    $end_date = $self->service->{end_date} if $self->renewal_type eq 'subscription_end';
    my $first_cost = $self->get_cost('ggw_cost_renewal_first', $end_date)
        || $self->get_cost('ggw_cost_first', $end_date);
    return $self->per_bin_renewal unless $first_cost;
    return $self->apply_garden_discount($first_cost);
}

sub per_sack_renewal { $_[0]->sacks_renewal(1) }
sub per_pro_rata_bin { $_[0]->pro_rata_cost(1) }

sub get_cost {
    my ($self, $cost_ref, $date) = @_;
    my $payments = $self->payments or return;
    my $cost = $payments->{$cost_ref};
    if (ref $cost eq 'ARRAY') {
        $cost = $self->_get_cost_from_array($cost, $date);
    }
    return $cost;
}

# Provided with a list of costs, and optionally a date string or DateTime object
sub _get_cost_from_array {
    my ($self, $costs, $date) = @_;

    # Default date if not provided to the current date
    $date ||= DateTime->now->set_time_zone(FixMyStreet->local_time_zone);
    $date = $date->strftime('%Y-%m-%d %H:%M') if ref $date; # A DateTime
    $date .= ' 00:00' if $date =~ /^\d\d\d\d-\d\d-\d\d$/; # If only a date provided

    my @sorted = sort { $b->{start_date} cmp $a->{start_date} } @$costs;
    foreach my $cost (@sorted) {
        return $cost->{cost} if $cost->{start_date} le $date;
    }

    die("Couldn't find a valid cost item");
}

1;
