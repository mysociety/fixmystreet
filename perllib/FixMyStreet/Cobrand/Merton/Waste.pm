package FixMyStreet::Cobrand::Merton::Waste;

use Moo::Role;
with 'FixMyStreet::Roles::Cobrand::Waste';
with 'FixMyStreet::Roles::Cobrand::SLWP';
with 'FixMyStreet::Roles::Cobrand::Adelante';

use FixMyStreet::App::Form::Waste::Report::Merton;
use FixMyStreet::App::Form::Waste::Request::Merton;

has lpi_value => ( is => 'ro', default => 'MERTON' );

sub waste_check_staff_payment_permissions {
    my $self = shift;
    my $c = $self->{c};

    return unless $c->stash->{is_staff};

    $c->stash->{staff_payments_allowed} = 'cnp';
}

sub waste_auto_confirm_report { 1 }

sub service_name_override {
    my ($self, $service) = @_;

    my %service_name_override = (
        2238 => 'Non-recyclable waste',
        2239 => 'Food waste',
        2240 => 'Paper and card',
        2241 => 'Mixed recycling',
        2242 => 'Non-recyclable waste',
        2243 => 'Non-recyclable waste',
        2246 => 'Mixed recycling',
        2247 => 'Garden waste',
        2248 => "Food waste",
        2249 => "Paper and card",
        2250 => "Mixed recycling",
        2632 => 'Paper and card',
        2256 => '', # Deliver refuse bags
        2257 => '', # Deliver recycling bags
    );

    return $service_name_override{$service->{ServiceId}} // '';
}

sub waste_password_hidden { 1 }

sub waste_containers {
    return {
        1 => 'Black rubbish bin (140L)',
        2 => 'Black rubbish bin (240L)',
        3 => 'Black rubbish bin (360L)',
        35 => 'Black rubbish bin (180L)',

        4 => 'Refuse Blue Sack',
        5 => 'Refuse Black Sack',
        6 => 'Refuse Red Stripe Bag',

        12 => 'Green recycling bin (240L)',
        13 => 'Green recycling bin (360L)',
        16 => 'Green recycling box (55L)',

        17 => 'Recycling Purple Bag',
        18 => 'Recycling Blue Stripe Bag',
        29 => 'Recycling Single Use Bag',

        19 => 'Blue lid paper and cardboard bin (240L)',
        20 => 'Blue lid paper and cardboard bin (360L)',
        36 => 'Blue lid paper and cardboard bin (180L)',

        21 => 'Paper & Card Reusable Bag',
        22 => 'Paper Sacks',
        30 => 'Paper Single Use Bag',
        31 => 'Paper 55L Box',

        23 => 'Food waste bin (kitchen)',
        24 => 'Food waste bin (outdoor)',

        26 => 'Garden waste bin (240L)',
        27 => 'Garden waste bin (140L)',
        28 => 'Garden waste sacks',

        7 => 'Communal Refuse bin (240L)',
        8 => 'Communal Refuse bin (360L)',
        9 => 'Communal Refuse bin (660L)',
        10 => 'Communal Refuse bin (1100L)',
        11 => 'Communal Refuse Chamberlain',
        33 => 'Communal Refuse bin (140L)',
        34 => 'Communal Refuse bin (1280L)',
        14 => 'Communal Recycling bin (660L)',
        15 => 'Communal Recycling bin (1100L)',
        25 => 'Communal Food bin (240L)',
    };
}

sub _waste_containers_no_request { {
    4 => 1, # Refuse blue bag
    29 => 1, # Recycling Single Use Bag
    21 => 1, # Paper & Card Reusable bag
} }

sub image_for_unit {
    my ($self, $unit) = @_;
    my $base = '/i/waste-containers';
    my $service_id = $unit->{service_id};
    my $time_banded = $self->{c}->stash->{property_time_banded};

    return svg_container_sack('normal', '#3B3B3A') if $service_id eq 2242 && $time_banded;
    if (my $container = $unit->{request_containers}[0]) {
        return svg_container_sack('normal', '#BD63D1') if $container == 17;
    }

    my $images = {
        2238 => svg_container_bin('wheelie', '#333333'), # refuse
        2239 => "$base/caddy-brown-large", # food
        2240 => svg_container_bin("wheelie", '#767472', '#00A6D2', 1), # paper and card
        2241 => "$base/box-green-mix", # dry mixed
        2242 => svg_container_sack('stripe', '#F1506D'), # domestic refuse bag
        2243 => svg_container_bin('communal', '#767472', '#333333'), # Communal refuse
        2246 => svg_container_sack('stripe', '#3E50FA'), # domestic recycling bag
        2247 => svg_container_bin('wheelie', '#8B5E3D'), # garden
        2248 => svg_container_bin('wheelie', '#8B5E3D'), # Communal food
        #2249 => "$base/bin-grey-blue-lid-recycling", # Communal paper
        2250 => svg_container_bin('communal', '#41B28A'), # Communal recycling
        2632 => svg_container_sack('normal', '#D8D8D8'), # domestic paper bag
    };
    return $images->{$service_id};
}

sub _closed_event {
    my ($self, $event) = @_;
    return 1 if $event->{ResolvedDate};
    return 1 if $event->{ResolutionCodeId} && $event->{ResolutionCodeId} != 584; # Out of Stock
    return 0;
}

# TODO
sub waste_bulky_missed_blocked_codes {}

sub garden_collection_time { '6:30am' }
sub garden_waste_new_bin_admin_fee { 0 }

sub waste_quantity_max {
    return (
        2247 => 3, # Garden waste maximum
    );
}

# Not in the function below because it needs to set things needed before then
# (perhaps could be refactored better at some point). Used for new/renew
sub waste_garden_sub_payment_params {
    my ($self, $data) = @_;
    my $c = $self->{c};

    # Special sack form handling
    my $container = $data->{container_choice} || '';
    if ($container eq 'sack') {
        $data->{bin_count} = $data->{bins_wanted};
        $data->{new_bins} = $data->{bins_wanted};
        my $cost_pa = $c->cobrand->garden_waste_sacks_cost_pa() * $data->{bin_count};
        ($cost_pa) = $c->cobrand->apply_garden_waste_discount($cost_pa) if $data->{apply_discount};
        $c->set_param('payment', $cost_pa);
    }
}

sub waste_request_form_first_next {
    my $self = shift;
    return sub {
        my $data = shift;
        return 'about_you' if $data->{"container-18"} || $data->{"container-30"};
        return 'replacement';
    };
}

sub waste_munge_request_data {
    my ($self, $id, $data, $form) = @_;

    my $c = $self->{c};
    my $address = $c->stash->{property}->{address};
    my $container = $c->stash->{containers}{$id};
    my $quantity = 1;
    my $reason = $data->{request_reason} || '';
    my $nice_reason = $c->stash->{label_for_field}->($form, 'request_reason', $reason);

    my ($action_id, $reason_id);
    if ($reason eq 'damaged') {
        $action_id = 3; # Replace
        $reason_id = 2; # Damaged
    } elsif ($reason eq 'missing') {
        $action_id = 1; # Deliver
        $reason_id = 1; # Missing
    } elsif ($reason eq 'new_build') {
        $action_id = 1; # Deliver
        $reason_id = 4; # New
    } elsif ($reason eq 'more') {
        $action_id = 1; # Deliver
        $reason_id = 3; # Change capacity
    } else {
        # No reason, must be a bag
        $action_id = 1; # Deliver
        $reason_id = 3; # Change capacity
        $nice_reason = "Additional bag required";
    }

    if ($reason eq 'damaged' || $reason eq 'missing') {
        $data->{title} = "Request replacement $container";
    } elsif ($reason eq 'change_capacity') {
        $data->{title} = "Request exchange for $container";
    } else {
        $data->{title} = "Request new $container";
    }
    $data->{detail} = "Quantity: $quantity\n\n$address";
    $data->{detail} .= "\n\nReason: $nice_reason" if $nice_reason;

    $c->set_param('Action', join('::', ($action_id) x $quantity));
    $c->set_param('Reason', join('::', ($reason_id) x $quantity));
    $c->set_param('Container_Type', $id);
}

sub garden_due_days { 30 }

=head2 waste_munge_report_form_pages

Rename the button on the first report page if we're doing an additional collection

=cut

sub waste_munge_report_form_pages {
    my ($self, $page_list, $field_list) = @_;
    if ($self->{c}->get_param('additional')) {
        $page_list->[1]->{title} = 'Select additional collection';
        $page_list->[1]->{update_field_list} = sub {
            return { submit => { value => 'Request additional collection' } };
        };
    }
}

sub waste_munge_report_form_fields {
    my ($self, $field_list) = @_;
    $self->{c}->stash->{form_class} = 'FixMyStreet::App::Form::Waste::Report::SLWP';
}

sub waste_munge_enquiry_data {
    my ($self, $data) = @_;

    my $address = $self->{c}->stash->{property}->{address};
    $data->{title} = $data->{category};

    my $detail;
    foreach (sort grep { /^extra_/ } keys %$data) {
        $detail .= "$data->{$_}\n\n";
    }
    $detail .= $address;
    $data->{detail} = $detail;
}

=head2 Payment information

=cut

sub waste_payment_ref_council_code { 'LBM' }

sub waste_cc_payment_reference {
    my ($self, $p) = @_;
    my $type = 'GWS'; # Garden
    $type = 'BWC' if $p->category eq 'Bulky collection';
    return $self->waste_payment_ref_council_code . "-$type-" . $p->id;
}

1;
