package FixMyStreet::Cobrand::Merton::Waste;

use Moo::Role;
with 'FixMyStreet::Roles::Cobrand::SLWP';

use FixMyStreet::App::Form::Waste::Report::Merton;
use FixMyStreet::App::Form::Waste::Request::Merton;

has lpi_value => ( is => 'ro', default => 'MERTON' );

sub waste_auto_confirm_report { 1 }

sub service_name_override {
    my ($self, $service) = @_;

    my %service_name_override = (
        2238 => 'Non-recyclable Refuse',
        2239 => 'Food waste',
        2240 => 'Paper and card',
        2241 => 'Mixed recycling',
        2242 => 'Non-recyclable Refuse',
        2243 => 'Non-recyclable Refuse',
        2246 => 'Mixed recycling',
        2247 => 'Garden Waste',
        2248 => "Food waste",
        2249 => "Paper and card",
        2250 => "Mixed recycling",
        2632 => 'Paper and card',
        3571 => 'Mixed recycling',
        3576 => 'Non-recyclable Refuse',
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

sub image_for_unit {
    my ($self, $unit) = @_;
    my $base = '/i/waste-containers';
    my $service_id = $unit->{service_id};
    my $images = {
        2238 => "$base/bin-black", # refuse
        2239 => "$base/caddy-brown-large", # food
        2240 => "$base/bin-grey-blue-lid-recycling", # paper and card
        2241 => "$base/box-green-mix", # dry mixed
        2242 => "$base/sack-clear-red", # domestic refuse bag
        2243 => "$base/large-communal-grey-black-lid", # Communal refuse
        2246 => "$base/sack-clear-blue", # domestic recycling bag
        2247 => "$base/bin-brown", # garden
        #2248 => "$base/bin-brown", # Communal food
        #2249 => "$base/bin-grey-blue-lid-recycling", # Communal paper
        2250 => "$base/large-communal-green", # Communal recycling
        2632 => "$base/sack-clear", # domestic paper bag
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
sub garden_container_data_extract { }
sub waste_bulky_missed_blocked_codes {}

sub waste_quantity_max {
    return (
        2247 => 3, # Garden waste maximum
    );
}

sub waste_request_form_first_next {
    my $self = shift;
    return sub {
        my $data = shift;
        return 'about_you' if $data->{"container-18"} || $data->{"container-30"};
        return 'replacement';
    };
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

1;
