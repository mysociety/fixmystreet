package FixMyStreet::Cobrand::Sutton;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use utf8;
use Moo;
with 'FixMyStreet::Roles::Cobrand::Waste',
     'FixMyStreet::Roles::Cobrand::KingstonSutton',
     'FixMyStreet::Roles::Cobrand::SLWP2',
     'FixMyStreet::Roles::Cobrand::SCP';

use Digest::SHA qw(sha1_hex);
use Encode qw(encode_utf8);
use Hash::Util qw(lock_hash);

sub council_area_id { return 2498; }
sub council_area { return 'Sutton'; }
sub council_name { return 'Sutton Council'; }
sub council_url { return 'sutton'; }
sub admin_user_domain { 'sutton.gov.uk' }

my %TASK_IDS = (
    domestic_refuse => 2238,
    domestic_food => 2239,
    domestic_paper => 2240,
    domestic_mixed => 2241,
    domestic_refuse_bag => 2242,
    communal_refuse => 2243,
    domestic_mixed_bag => 2246,
    garden => 2247,
    communal_food => 2248,
    communal_paper => 2249,
    communal_mixed => 2250,
    domestic_paper_bag => 2632,
    schedule2_mixed => 3571,
    schedule2_refuse => 3576,
    deliver_refuse_bags => 2256,
    deliver_recycling_bags => 2257,
);
lock_hash(%TASK_IDS);

my %CONTAINERS = (
    refuse_140 => 1,
    refuse_180 => 35,
    refuse_240 => 2,
    refuse_360 => 3,
    recycling_box => 16,
    recycling_240 => 12,
    recycling_blue_bag => 18,
    paper_240 => 19,
    paper_140 => 36,
    paper_bag => 30,
    food_indoor => 23,
    food_outdoor => 24,
    garden_240 => 26,
    garden_140 => 27,
    garden_sack => 28,
);
lock_hash(%CONTAINERS);

=head2 waste_on_the_day_criteria

If it's before 6pm on the day of collection, treat an Outstanding/Allocated
task as if it's the next collection and in progress, do not allow missed
collection reporting, and do not show the collected time.

=cut

sub waste_on_the_day_criteria {
    my ($self, $completed, $state, $now, $row) = @_;

    return unless $now->hour < 18;
    if ($state eq 'Outstanding' || $state eq 'Allocated') {
        $row->{next} = $row->{last};
        $row->{next}{state} = 'In progress';
        delete $row->{last};
    }
    $row->{report_allowed} = 0; # No reports pre-6pm, completed or not
    if ($row->{last}) {
        # Prevent showing collected time until reporting is allowed
        $row->{last}{completed} = 0;
    }
}

sub waste_check_staff_payment_permissions {
    my $self = shift;
    my $c = $self->{c};

    return unless $c->stash->{is_staff};

    $c->stash->{staff_payments_allowed} = 'paye';
}

sub waste_payment_ref_council_code { "LBS" }

sub garden_collection_time { '6am' }

sub waste_garden_allow_cancellation { 'staff' }

sub waste_quantity_max {
    return (
        $TASK_IDS{garden} => 5, # Garden waste maximum
    );
}

sub waste_munge_bin_services_open_requests {
    my ($self, $open_requests) = @_;
    if ($open_requests->{$CONTAINERS{refuse_140}}) { # Sutton
        $open_requests->{$CONTAINERS{refuse_240}} = $open_requests->{$CONTAINERS{refuse_140}};
    } elsif ($open_requests->{$CONTAINERS{refuse_180}}) { # Kingston
        $open_requests->{$CONTAINERS{refuse_240}} = $open_requests->{$CONTAINERS{refuse_180}};
    } elsif ($open_requests->{$CONTAINERS{refuse_240}}) { # Both
        $open_requests->{$CONTAINERS{refuse_140}} = $open_requests->{$CONTAINERS{refuse_240}};
        $open_requests->{$CONTAINERS{refuse_180}} = $open_requests->{$CONTAINERS{refuse_240}};
        $open_requests->{$CONTAINERS{refuse_360}} = $open_requests->{$CONTAINERS{refuse_240}};
    } elsif ($open_requests->{$CONTAINERS{refuse_360}}) { # Kingston
        $open_requests->{$CONTAINERS{refuse_180}} = $open_requests->{$CONTAINERS{refuse_360}};
        $open_requests->{$CONTAINERS{refuse_240}} = $open_requests->{$CONTAINERS{refuse_360}};
    }
    if ($open_requests->{$CONTAINERS{paper_140}}) {
        $open_requests->{$CONTAINERS{paper_240}} = $open_requests->{$CONTAINERS{paper_140}};
    }
}

sub image_for_unit {
    my ($self, $unit) = @_;
    my $base = '/i/waste-containers';
    if (my $container = $unit->{garden_container}) {
        return svg_container_bin("wheelie", '#41B28A', '#8B5E3D') if $container == $CONTAINERS{garden_240} || $container == $CONTAINERS{garden_140};
        return svg_container_sack('normal', '#F5F5DC') if $container == $CONTAINERS{garden_sack};
        return "";
    }
    if (my $container = $unit->{request_containers}[0]) {
        return "$base/caddy-brown-large" if $container == 24;
    }
    my $service_id = $unit->{service_id};
    if ($service_id eq 'bulky') {
        return "$base/bulky-black";
    }
    if ($service_id == 2243 && $unit->{schedule} =~ /fortnight/i) {
        # Communal fortnightly is a wheelie bin, not a large bin
        return svg_container_bin('wheelie', '#8B5E3D');
    }
    my $images = {
        $TASK_IDS{domestic_refuse} => svg_container_bin('wheelie', '#8B5E3D'),
        $TASK_IDS{domestic_food} => "$base/caddy-brown-large",
        $TASK_IDS{domestic_paper} => svg_container_bin('wheelie', '#41B28A'),
        $TASK_IDS{domestic_mixed} => "$base/box-green-mix",
        $TASK_IDS{domestic_refuse_bag} => svg_container_sack('stripe', '#E83651'),
        $TASK_IDS{communal_refuse} => svg_container_bin('communal', '#767472', '#333333'),
        $TASK_IDS{domestic_mixed_bag} => svg_container_sack('stripe', '#4f4cf0'),
        $TASK_IDS{communal_food} => svg_container_bin('wheelie', '#8B5E3D'),
        $TASK_IDS{communal_paper} => svg_container_bin("wheelie", '#767472', '#00A6D2', 1),
        $TASK_IDS{communal_mixed} => svg_container_bin('communal', '#41B28A'),
        $TASK_IDS{domestic_paper_bag} => svg_container_sack('normal', '#d8d8d8'),
    };
    return $images->{$service_id};
}

sub waste_containers {
    my $self = shift;
    return {
        4 => 'Refuse Blue Sack',
        5 => 'Refuse Black Sack',
        6 => 'Refuse Red Stripe Bag',
        18 => 'Mixed Recycling Blue Striped Bag',
        29 => 'Recycling Single Use Bag',
        21 => 'Paper & Card Reusable Bag',
        22 => 'Paper Sacks',
        30 => 'Paper & Card Recycling Clear Bag',
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
        $CONTAINERS{recycling_240} => 'Recycling bin (240L)',
        13 => 'Recycling bin (360L)',
        20 => 'Paper recycling bin (360L)',
        31 => 'Paper 55L Box',
        $CONTAINERS{refuse_140} => 'Standard Brown General Waste Wheelie Bin (140L)',
        $CONTAINERS{refuse_240} => 'Larger Brown General Waste Wheelie Bin (240L)',
        $CONTAINERS{refuse_360} => 'Extra Large Brown General Waste Wheelie Bin (360L)',
        $CONTAINERS{refuse_180} => 'Rubbish bin (180L)',
        $CONTAINERS{recycling_box} => 'Mixed Recycling Green Box (55L)',
        $CONTAINERS{paper_240} => 'Paper and Cardboard Green Wheelie Bin (240L)',
        $CONTAINERS{paper_140} => 'Paper and Cardboard Green Wheelie Bin (140L)',
        $CONTAINERS{food_indoor} => 'Small Kitchen Food Waste Caddy (7L)',
        $CONTAINERS{food_outdoor} => 'Large Outdoor Food Waste Caddy (23L)',
        $CONTAINERS{garden_240} => 'Garden Waste Wheelie Bin (240L)',
        $CONTAINERS{garden_140} => 'Garden Waste Wheelie Bin (140L)',
        $CONTAINERS{garden_sack} => 'Garden waste sacks',
    };
}

=head2 service_name_override

Customer facing names for services

=cut

sub service_name_override {
    my ($self, $service) = @_;

    my %service_name_override = (
        $TASK_IDS{domestic_refuse} => 'Non-Recyclable Refuse',
        $TASK_IDS{domestic_food} => 'Food Waste',
        $TASK_IDS{domestic_paper} => 'Paper & Card',
        $TASK_IDS{domestic_mixed} => 'Mixed Recycling (Cans, Plastics & Glass)',
        $TASK_IDS{domestic_refuse_bag} => 'Non-Recyclable Refuse',
        $TASK_IDS{communal_refuse} => 'Non-Recyclable Refuse',
        $TASK_IDS{domestic_mixed_bag} => 'Mixed Recycling (Cans, Plastics & Glass)',
        $TASK_IDS{garden} => 'Garden Waste',
        $TASK_IDS{communal_food} => 'Food Waste',
        $TASK_IDS{communal_paper} => 'Paper & Card',
        $TASK_IDS{communal_mixed} => 'Mixed Recycling (Cans, Plastics & Glass)',
        $TASK_IDS{domestic_paper_bag} => 'Paper & Card',
        $TASK_IDS{schedule2_mixed} => 'Mixed Recycling (Cans, Plastics & Glass)',
        $TASK_IDS{schedule2_refuse} => 'Non-Recyclable Refuse',
        $TASK_IDS{deliver_refuse_bags} => '',
        $TASK_IDS{deliver_recycling_bags} => '',
    );

    return $service_name_override{$service->{ServiceId}} // '';
}

sub waste_request_single_radio_list { 1 }

=head2 waste_munge_request_form_fields

Replace the usual checkboxes grouped by service with one radio list of
containers.

=cut

sub waste_munge_request_form_fields {
    my ($self, $field_list) = @_;
    my $c = $self->{c};

    my @radio_options;
    my @replace_options;
    my $costs = WasteWorks::Costs->new({ cobrand => $self });
    my $change_cost = $costs->get_cost('request_change_cost');
    for (my $i=0; $i<@$field_list; $i+=2) {
        my ($key, $value) = ($field_list->[$i], $field_list->[$i+1]);
        next unless $key =~ /^container-(\d+)/;
        my $id = $1;

        my ($cost, $hint) = $self->request_cost($id, 1, $c->stash->{quantities});

        my $data = {
            value => $id,
            label => $self->{c}->stash->{containers}->{$id},
            disabled => $value->{disabled},
            $hint ? (hint => $hint) : (),
        };
        if ($cost && $change_cost && $cost == $change_cost) {
            push @replace_options, $data;
        } else {
            push @radio_options, $data;
        }
    }

    if (@replace_options) {
        $radio_options[0]{tags}{divider_template} = "waste/request/intro_replace";
        $replace_options[0]{tags}{divider_template} = "waste/request/intro_change";
        push @radio_options, @replace_options;
    }

    @$field_list = (
        "container-choice" => {
            type => 'Select',
            widget => 'RadioGroup',
            label => 'Which container do you need?',
            options => \@radio_options,
            required => 1,
        }
    );
}

=head2 waste_request_form_first_next

After picking a container, we jump straight to the about you page if they've
picked a bag or changing size; otherwise we move to asking for a reason.

=cut

sub waste_request_form_first_title { 'Which container do you need?' }
sub waste_request_form_first_next {
    my $self = shift;
    my $containers = $self->{c}->stash->{quantities};
    return sub {
        my $data = shift;
        my $choice = $data->{"container-choice"};
        return 'about_you' if $choice == $CONTAINERS{recycling_blue_bag} || $choice == $CONTAINERS{paper_bag};
        foreach ($CONTAINERS{refuse_140}, $CONTAINERS{refuse_240}, $CONTAINERS{paper_240}) {
            if ($choice == $_ && !$containers->{$_}) {
                $data->{request_reason} = 'change_capacity';
                return 'about_you';
            }
        }
        return 'replacement';
    };
}

# Take the chosen container and munge it into the normal data format
sub waste_munge_request_form_data {
    my ($self, $data) = @_;
    my $container_id = delete $data->{'container-choice'};
    $data->{"container-$container_id"} = 1;
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
    } elsif ($reason eq 'change_capacity') {
        $action_id = '2::1';
        $reason_id = '3::3';
        if ($id == $CONTAINERS{refuse_140}) {
            $id = $CONTAINERS{refuse_240} . '::' . $CONTAINERS{refuse_140};
        } elsif ($id == $CONTAINERS{refuse_240}) {
            if ($c->stash->{quantities}{+$CONTAINERS{refuse_360}}) {
                $id = $CONTAINERS{refuse_360} . '::' . $CONTAINERS{refuse_240};
            } else {
                $id = $CONTAINERS{refuse_140} . '::' . $CONTAINERS{refuse_240};
            }
        } elsif ($id == $CONTAINERS{paper_240}) {
            $id = $CONTAINERS{paper_140} . '::' . $CONTAINERS{paper_240};
        }
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

=head2 request_cost

Calculate how much, if anything, a request for a container should be.
Quantity doesn't matter here.

=cut

sub request_cost {
    my ($self, $id, $quantity, $containers) = @_;
    my $costs = WasteWorks::Costs->new({ cobrand => $self });
    if (my $cost = $costs->get_cost('request_change_cost')) {
        foreach ($CONTAINERS{refuse_140}, $CONTAINERS{refuse_240}, $CONTAINERS{paper_240}) {
            if ($id == $_ && !$containers->{$_}) {
                my $price = sprintf("£%.2f", $cost / 100);
                $price =~ s/\.00$//;
                my $hint = "There is a $price administration/delivery charge to change the size of your container";
                return ($cost, $hint);
            }
        }
    }
    if (my $cost = $costs->get_cost('request_replace_cost')) {
        foreach ($CONTAINERS{refuse_140}, $CONTAINERS{refuse_240}, $CONTAINERS{refuse_360}, $CONTAINERS{paper_240}) {
            if ($id == $_ && $containers->{$_}) {
                my $price = sprintf("£%.2f", $cost / 100);
                $price =~ s/\.00$//;
                my $hint = "There is a $price administration/delivery charge to replace your container";
                return ($cost, $hint);
            }
        }
    }
}

=head2 Bulky waste collection

Sutton starts collections at 6am, and lets you cancel up until 6am.

=cut

sub bulky_allowed_property {
    my ( $self, $property ) = @_;
    my $cfg = $self->feature('echo');
    my $type = $property->{type_id} || 0;
    my $valid_type = grep { $_ == $type } @{ $cfg->{bulky_address_types} || [] };
    return $self->bulky_enabled && $property->{has_bulky_service} && $valid_type;
}

sub bulky_collection_time { { hours => 6, minutes => 0 } }
sub bulky_cancellation_cutoff_time { { hours => 6, minutes => 0, days_before => 0 } }

=head2 bulky_collection_window_start_date

K&S have an 11pm cut-off for looking to book next day collections.

=cut

sub bulky_collection_window_start_date {
    my ($self, $now) = @_;
    my $start_date = $now->clone->truncate( to => 'day' )->add( days => 1 );
    # If past 11pm, push start date one day later
    if ($now->hour >= 23) {
        $start_date->add( days => 1 );
    }
    return $start_date;
}

1;
