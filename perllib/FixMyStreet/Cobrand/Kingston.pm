package FixMyStreet::Cobrand::Kingston;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use Moo;
with 'FixMyStreet::Roles::CobrandSLWP';
with 'FixMyStreet::Roles::Bottomline';
with 'FixMyStreet::Roles::SCP';

sub council_area_id { return 2480; }
sub council_area { return 'Kingston'; }
sub council_name { return 'Kingston upon Thames Council'; }
sub council_url { return 'kingston'; }

sub admin_user_domain { ('kingston.gov.uk', 'sutton.gov.uk') }

sub dashboard_extra_bodies {
    my $sutton = FixMyStreet::Cobrand::Sutton->new->body;
    return $sutton;
}

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
    return "$base/bin-green" if $containers{12} && $self->{c}->stash->{container_recycling_bin};
    return "$base/box-green-mix" if $containers{16};

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

=head2 Bulky waste collection

Kingston starts collections at 6:30am, and lets you cancel up until then.

=cut

sub bulky_collection_time { { hours => 6, minutes => 30 } }
sub bulky_cancellation_cutoff_time { { hours => 6, minutes => 30 } }

1;
