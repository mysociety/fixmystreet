=head1 NAME

FixMyStreet::Roles::Cobrand::Waste - cobrand functions shared with all waste clients

=cut

package FixMyStreet::Roles::Cobrand::Waste;

use Moo::Role;
use Path::Tiny;

sub bin_payment_types {
    return {
        'csc' => 1,
        'credit_card' => 2,
        'direct_debit' => 3,
        'cheque' => 4,
    };
}

=head2 svg_container_sack

TYPE is either 'normal' or 'stripe'.

=cut

sub svg_container_sack {
    my ($type, $colour) = @_;
    my $dir = path(FixMyStreet->path_to("web/i/waste-containers"));
    $type = ($type eq 'stripe') ? 'sack-stripe' : 'sack';
    return {
        type => 'svg',
        data => $dir->child("$type.svg")->slurp_raw,
        colour => $colour,
    };
}

=head2 svg_container_bin

TYPE is either 'wheelie' or 'communal'.

=cut

sub svg_container_bin {
    my ($type, $colour_main, $colour_lid, $recycling_logo) = @_;
    my $dir = path(FixMyStreet->path_to("web/i/waste-containers"));
    return {
        type => 'svg',
        data => $dir->child("$type.svg")->slurp_raw,
        colour => $colour_main,
        lid_colour => $colour_lid,
        recycling_logo => $recycling_logo,
    };
}

sub svg_container_box {
    my ($colour, $recycling_logo) = @_;
    my $dir = path(FixMyStreet->path_to("web/i/waste-containers"));
    return {
        type => 'svg',
        data => $dir->child("box.svg")->slurp_raw,
        colour => $colour,
        recycling_logo => $recycling_logo,
    };
}

# Garden related

sub garden_subscription_email_renew_reminder_opt_in { 0 }

sub garden_waste_sacks_cost_pa {
    my ($self) = @_;
    return $self->_get_cost('ggw_sacks_cost');
}

sub garden_waste_cost_pa {
    my ($self, $bin_count) = @_;
    $bin_count ||= 1;
    my $per_bin_cost = $self->_get_cost('ggw_cost');
    my $cost = $per_bin_cost * $bin_count;
    return $cost;
}

# Same as full cost
sub waste_get_pro_rata_cost {
    my ($self, $bins, $end) = @_;
    return $self->garden_waste_cost_pa($bins);
}

=head2 garden_waste_cost_pa_in_one_month

Returns the cost of garden waste in one month, if it differs from the usual
cost passed in. This is to show an upcoming price change on the garden
subscription intro page.

=cut

sub garden_waste_cost_pa_in_one_month {
    my ($self, $cost_pa) = @_;

    my $costs = $self->feature('payment_gateway');
    return unless $costs;
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

sub garden_waste_renewal_cost_pa {
    my ($self, $end_date, $bin_count) = @_;
    return $self->garden_waste_cost_pa($bin_count);
}

sub garden_waste_renewal_sacks_cost_pa {
    my ($self, $end_date) = @_;
    return $self->garden_waste_sacks_cost_pa();
}

sub garden_waste_new_bin_admin_fee { 0 }

sub waste_cheque_payments { 0 }

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

sub _get_cost {
    my ($self, $cost_ref, $date) = @_;
    my $payments = $self->feature('payment_gateway');
    my $cost = $payments->{$cost_ref};
    if (ref $cost eq 'ARRAY') {
        $cost = $self->_get_cost_from_array($cost, $date);
    }
    return $cost;
}

1;
