package FixMyStreet::Cobrand::Kingston;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use utf8;
use Moo;
with 'FixMyStreet::Roles::CobrandSLWP';
with 'FixMyStreet::Roles::SCP';

sub council_area_id { return 2480; }
sub council_area { return 'Kingston'; }
sub council_name { return 'Kingston upon Thames Council'; }
sub council_url { return 'kingston'; }
sub admin_user_domain { 'kingston.gov.uk' }

use constant CONTAINER_RECYCLING_BIN => 12;
use constant CONTAINER_RECYCLING_BOX => 16;

=head2 waste_on_the_day_criteria

Treat an Outstanding/Allocated task as if it's the next collection and in
progress, and do not allow missed collection reporting if the task is not
completed.

=cut

sub waste_on_the_day_criteria {
    my ($self, $completed, $state, $now, $row) = @_;

    if ($state eq 'Outstanding' || $state eq 'Allocated') {
        $row->{next} = $row->{last};
        $row->{next}{state} = 'In progress';
        delete $row->{last};
    }
    if (!$completed) {
        $row->{report_allowed} = 0;
    }
}

sub waste_check_staff_payment_permissions {
    my $self = shift;
    my $c = $self->{c};

    return unless $c->stash->{is_staff};

    $c->stash->{staff_payments_allowed} = 'cnp';
}

has lpi_value => ( is => 'ro', default => 'KINGSTON UPON THAMES' );

sub waste_payment_ref_council_code { "RBK" }

sub garden_collection_time { '6:30am' }

sub image_for_unit {
    my ($self, $unit) = @_;
    my $base = '/i/waste-containers';
    if (my $container = $unit->{garden_container}) {
        return "$base/bin-grey-green-lid-recycling" if $container == 26 || $container == 27;
        return "";
    }

    if ($unit->{service_id} eq 'bulky') {
        return "$base/bulky-black";
    }

    # Base mixed recycling (2241) on the container itself
    my %containers = map { $_ => 1 } @{$unit->{request_containers}};
    return "$base/bin-green" if $containers{+CONTAINER_RECYCLING_BIN};
    return "$base/box-green-mix" if $containers{+CONTAINER_RECYCLING_BOX};

    my $service_id = $unit->{service_id};
    my $images = {
        2238 => "$base/bin-black", # refuse
        2239 => "$base/caddy-brown-large", # food
        2240 => "$base/bin-grey-blue-lid-recycling", # paper and card
        2241 => "$base/bin-green", # dry mixed
        2242 => "$base/sack-clear-red", # domestic refuse bag
        2243 => "$base/large-communal-grey-black-lid", # Communal refuse
        2246 => "$base/sack-clear-blue", # domestic recycling bag
        2248 => "$base/bin-brown", # Communal food
        2249 => "$base/large-communal-grey-blue-lid", # Communal paper
        2250 => "$base/large-communal-green", # Communal recycling
        2632 => "$base/sack-clear", # domestic paper bag
    };
    return $images->{$service_id};
}

=head2 garden_waste_renewal_cost_pa

The price change for a renewal is based upon the end
date of the subscription, not the current date.

=cut

sub garden_waste_renewal_cost_pa {
     my ($self, $end_date, $bin_count) = @_;
     $bin_count ||= 1;
     my $per_bin_cost = $self->_get_cost('ggw_cost_renewal', $end_date);
     my $cost = $per_bin_cost * $bin_count;
     return $cost;
}

sub garden_waste_renewal_sacks_cost_pa {
     my ($self, $end_date) = @_;
     return $self->_get_cost('ggw_sacks_cost_renewal', $end_date);
}

=head2 waste_request_form_first_next

After picking a container, we jump straight to the about you page

=cut

sub waste_request_form_first_title { 'Which container do you need?' }
sub waste_request_form_first_next {
    my $self = shift;
    my $cls = ucfirst $self->council_url;
    my $containers = $self->{c}->stash->{quantities};
    return sub {
        my $data = shift;
        my $choice = $data->{"container-choice"};
        return 'about_you';
    };
}

sub waste_munge_request_data {
    my ($self, $id, $data, $form) = @_;

    my $c = $self->{c};
    my $address = $c->stash->{property}->{address};
    my $container = $c->stash->{containers}{$id};
    my $quantity = 1;

    my ($action_id, $reason_id);
    $action_id = 1; # Deliver
    $reason_id = 1; # Missing

    $data->{title} = "Request $container";
    $data->{detail} = "Quantity: $quantity\n\n$address";

    $c->set_param('Action', join('::', ($action_id) x $quantity));
    $c->set_param('Reason', join('::', ($reason_id) x $quantity));
    $c->set_param('Container_Type', $id);
}

=head2 request_cost

Calculate how much, if anything, a request for a container should be.

=cut

sub request_cost {
    my ($self, $id, $quantity, $containers) = @_;
    $quantity ||= 1;
    if (my $cost = $self->_get_cost('request_replace_cost')) {
        my $cost_more = $self->_get_cost('request_replace_cost_more') || $cost/2;
        if ($quantity > 1) {
            $cost += $cost_more * ($quantity-1);
        }
        my $names = $self->{c}->stash->{containers};
        if ($names->{$id} !~ /bag|sack|food/i) {
            my $hint = "";
            return ($cost, $hint);
        }
    }
}

=head2 Bulky waste collection

Kingston starts collections at 6:30am, and lets you cancel up until then.

=cut

sub bulky_collection_time { { hours => 6, minutes => 30 } }
sub bulky_cancellation_cutoff_time { { hours => 6, minutes => 30, days_before => 0 } }

1;
