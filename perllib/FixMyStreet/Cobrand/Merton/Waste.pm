package FixMyStreet::Cobrand::Merton::Waste;

use utf8;
use Moo::Role;
with 'FixMyStreet::Roles::Cobrand::Waste',
     'FixMyStreet::Roles::Cobrand::SLWP2',
     'FixMyStreet::Roles::Cobrand::Adelante';

use Hash::Util qw(lock_hash);
use WasteWorks::Costs;
use FixMyStreet::App::Form::Waste::Report::Merton;
use FixMyStreet::App::Form::Waste::Request::Merton;
use FixMyStreet::App::Form::Waste::Request::Merton::Larger;

my %SERVICE_IDS = (
    domestic_refuse => 1067, # 4394
    communal_refuse => 1070, # 4407
    fas_refuse => 1068, # 4395
    domestic_mixed => 1071, # 4390
    communal_mixed => 1074, # 4397
    fas_mixed => 1072, # 4391
    domestic_paper => 1075, # 4388
    communal_paper => 1078, # 4396
    fas_paper => 1076, # 4402
    domestic_food => 1084, # 4389
    communal_food => 1087, # 4403
    garden => 1082, # 4410
    schedule2_refuse => 1069, # 4409
    schedule2_mixed => 1073, # 4398
    deliver_bags => 1090, # 4427 4432
);
lock_hash(%SERVICE_IDS);

my %CONTAINERS = (
    refuse_180 => 2,
    refuse_240 => 3,
    refuse_360 => 4,
    refuse_red_stripe_bag => 10,
    refuse_black_bag => 11,
    recycling_box => 12,
    recycling_180 => 14,
    recycling_240 => 15,
    recycling_360 => 16,
    recycling_blue_stripe_bag => 22,
    recycling_purple_bag => 23,
    paper_180 => 26,
    paper_240 => 27,
    paper_360 => 28,
    paper_bag => 34,
    food_indoor => 44,
    food_outdoor => 46,
    food_120 => 49,
    food_140 => 48,
    food_240 => 51,
    garden_240 => 39,
    garden_140 => 37,
    garden_sack => 36,

    refuse_660 => 5,
    refuse_1100 => 8,
    recycling_660 => 17,
    recycling_1100 => 20,
    paper_660 => 29,
    paper_1100 => 32,
);
lock_hash(%CONTAINERS);

# Merton staff can order any container, and if they do we need a way to map
# the chosen container to a service to send to Echo (for normal users, the
# container will be within the relevant service).
my %container_to_service = (
    $CONTAINERS{refuse_180} => $SERVICE_IDS{domestic_refuse},
    $CONTAINERS{refuse_240} => $SERVICE_IDS{domestic_refuse},
    $CONTAINERS{refuse_360} => $SERVICE_IDS{domestic_refuse},
    $CONTAINERS{refuse_red_stripe_bag} => $SERVICE_IDS{domestic_refuse},
    $CONTAINERS{refuse_black_bag} => $SERVICE_IDS{fas_refuse},

    $CONTAINERS{recycling_180} => $SERVICE_IDS{domestic_mixed},
    $CONTAINERS{recycling_240} => $SERVICE_IDS{domestic_mixed},
    $CONTAINERS{recycling_360} => $SERVICE_IDS{domestic_mixed},
    $CONTAINERS{recycling_box} => $SERVICE_IDS{domestic_mixed},
    $CONTAINERS{recycling_blue_stripe_bag} => $SERVICE_IDS{domestic_mixed},
    $CONTAINERS{recycling_purple_bag} => $SERVICE_IDS{fas_mixed},

    $CONTAINERS{paper_240} => $SERVICE_IDS{domestic_paper},
    $CONTAINERS{paper_360} => $SERVICE_IDS{domestic_paper},
    $CONTAINERS{paper_180} => $SERVICE_IDS{domestic_paper},
    $CONTAINERS{paper_bag} => $SERVICE_IDS{domestic_paper},

    $CONTAINERS{food_indoor} => $SERVICE_IDS{domestic_food},
    $CONTAINERS{food_outdoor} => $SERVICE_IDS{domestic_food},

    $CONTAINERS{garden_240} => $SERVICE_IDS{garden},
    $CONTAINERS{garden_140} => $SERVICE_IDS{garden},
    $CONTAINERS{garden_sack} => $SERVICE_IDS{garden},

    $CONTAINERS{refuse_660} => $SERVICE_IDS{communal_refuse},
    $CONTAINERS{refuse_1100} => $SERVICE_IDS{communal_refuse},
    $CONTAINERS{recycling_660} => $SERVICE_IDS{communal_mixed},
    $CONTAINERS{recycling_1100} => $SERVICE_IDS{communal_mixed},
    $CONTAINERS{paper_660} => $SERVICE_IDS{communal_paper},
    $CONTAINERS{paper_1100} => $SERVICE_IDS{communal_paper},
    $CONTAINERS{food_120} => $SERVICE_IDS{communal_food},
    $CONTAINERS{food_140} => $SERVICE_IDS{communal_food},
    $CONTAINERS{food_240} => $SERVICE_IDS{communal_food},
);

=over 4

=item * Merton has a Saturday 1 July date format

=cut

sub bin_day_format { '%A %-d %B' }

=item * Merton calendars only look two weeks into the future

=cut

sub bin_future_timeframe { ( days => 15 ) }

sub waste_check_staff_payment_permissions {
    my $self = shift;
    my $c = $self->{c};

    return unless $c->stash->{is_staff};

    $c->stash->{staff_payments_allowed} = 'cnp';
}

sub waste_auto_confirm_report { 1 }

sub waste_cancel_asks_staff_for_user_details { 1 }

sub service_name_override {
    my ($self, $service) = @_;

    my %service_name_override = (
        $SERVICE_IDS{domestic_refuse} => 'Non-recyclable waste',
        $SERVICE_IDS{domestic_food} => 'Food waste',
        $SERVICE_IDS{domestic_paper} => 'Paper and card',
        $SERVICE_IDS{domestic_mixed} => 'Mixed recycling',
        $SERVICE_IDS{fas_refuse} => 'Non-recyclable waste',
        $SERVICE_IDS{communal_refuse} => 'Non-recyclable waste',
        $SERVICE_IDS{fas_mixed} => 'Mixed recycling',
        $SERVICE_IDS{garden} => 'Garden Waste',
        $SERVICE_IDS{communal_food} => 'Food waste',
        $SERVICE_IDS{communal_paper} => 'Paper and card',
        $SERVICE_IDS{communal_mixed} => 'Mixed recycling',
        $SERVICE_IDS{fas_paper} => 'Paper and card',
        $SERVICE_IDS{deliver_bags} => '',
    );

    return $service_name_override{$service->{ServiceId}} // '';
}

sub waste_password_hidden { 1 }

sub waste_containers {
    return {
        $CONTAINERS{refuse_180} => 'Black rubbish bin (180L)',
        $CONTAINERS{refuse_240} => 'Black rubbish bin (240L)',
        $CONTAINERS{refuse_360} => 'Black rubbish bin (360L)',
        $CONTAINERS{refuse_red_stripe_bag} => 'Refuse Red Stripe Bag',
        $CONTAINERS{refuse_black_bag} => 'Refuse Black Sack',

        $CONTAINERS{recycling_180} => 'Green recycling bin (180L)',
        $CONTAINERS{recycling_240} => 'Green recycling bin (240L)',
        $CONTAINERS{recycling_360} => 'Green recycling bin (360L)',
        $CONTAINERS{recycling_box} => 'Green recycling box (55L)',
        $CONTAINERS{recycling_blue_stripe_bag} => 'Recycling Blue Stripe Bag',
        $CONTAINERS{recycling_purple_bag} => 'Recycling Purple Bag',

        $CONTAINERS{paper_240} => 'Blue lid paper and cardboard bin (240L)',
        $CONTAINERS{paper_360} => 'Blue lid paper and cardboard bin (360L)',
        $CONTAINERS{paper_180} => 'Blue lid paper and cardboard bin (180L)',

        $CONTAINERS{paper_bag} => 'Paper & Card Reusable Bag',

        $CONTAINERS{food_indoor} => 'Food waste bin (kitchen)',
        $CONTAINERS{food_outdoor} => 'Food waste bin (outdoor)',

        $CONTAINERS{garden_240} => 'Garden waste bin (240L)',
        $CONTAINERS{garden_140} => 'Garden waste bin (140L)',
        $CONTAINERS{garden_sack} => 'Garden waste sacks',

        $CONTAINERS{refuse_660} => 'Communal Refuse bin (660L)',
        $CONTAINERS{refuse_1100} => 'Communal Refuse bin (1100L)',
        $CONTAINERS{recycling_660} => 'Communal Recycling bin (660L)',
        $CONTAINERS{recycling_1100} => 'Communal Recycling bin (1100L)',
        $CONTAINERS{paper_660} => 'Communal paper bin (660L)',
        $CONTAINERS{paper_1100} => 'Communal paper bin (1100L)',
        $CONTAINERS{food_120} => 'Communal food bin (120L)',
        $CONTAINERS{food_140} => 'Communal food bin (140L)',
        $CONTAINERS{food_240} => 'Communal food bin (240L)',
    };
}

sub _waste_containers_no_request { return {
    $CONTAINERS{refuse_black_bag} => 1,
} }

sub image_for_unit {
    my ($self, $unit) = @_;
    my $base = '/i/waste-containers';
    my $service_id = $unit->{service_id};
    my $container = $unit->{request_containers}[0] || 0;

    my $images = {
        $CONTAINERS{refuse_black_bag} => svg_container_sack('normal', '#3B3B3A'),
        $CONTAINERS{recycling_purple_bag} => svg_container_sack('normal', '#BD63D1'),
        $CONTAINERS{recycling_blue_stripe_bag} => svg_container_sack('stripe', '#3E50FA'),
        $CONTAINERS{refuse_red_stripe_bag} => svg_container_sack('stripe', '#F1506D'),
        $CONTAINERS{paper_bag} => svg_container_sack('normal', '#D8D8D8'),

        # Fallback to the service if no container match
        $SERVICE_IDS{domestic_refuse} => svg_container_bin('wheelie', '#333333'),
        $SERVICE_IDS{domestic_food} => "$base/caddy-brown-large",
        $SERVICE_IDS{domestic_paper} => svg_container_bin("wheelie", '#767472', '#00A6D2', 1),
        $SERVICE_IDS{domestic_mixed} => "$base/box-green-mix",
        $SERVICE_IDS{communal_refuse} => svg_container_bin('communal', '#767472', '#333333'),
        $SERVICE_IDS{garden} => svg_container_bin('wheelie', '#8B5E3D'),
        $SERVICE_IDS{communal_food} => svg_container_bin('wheelie', '#8B5E3D'),
        $SERVICE_IDS{communal_mixed} => svg_container_bin('communal', '#41B28A'),
        bulky => "$base/bulky-black",
    };
    return $images->{$container} || $images->{$service_id};
}

sub garden_collection_time { '6:00am' }

=head2 garden_subscription_start_days

Call hook to return the number of days before a new garden
subscription starts. Merton vary this depending on whether
there are bins to be delivered.

=cut

sub garden_subscription_start_days {
    my ($self, $data) = @_;
    return $data->{new_bins} && $data->{new_bins} > 0 ? 5 : 0;
}

sub waste_renewal_bins_wanted_disabled { 1 }

=item * SLWP Echo uses End_Date for garden cancellations

=cut

sub alternative_backend_field_names {
    my ($self, $field) = @_;

    my %alternative_name = (
        'Subscription_End_Date' => 'End_Date',
    );

    return $alternative_name{$field};
}

sub waste_garden_maximum { 3 }

=item munge_bin_services_for_address

Merton want staff to be able to request any domestic container
for a property and also to not be restricted to only ordering
one container.

=cut

sub munge_bin_services_for_address {
    my ($self, $rows) = @_;

    return if $self->{c}->stash->{schedule2_property};

    foreach (@$rows) {
        if ($_->{service_id} eq $SERVICE_IDS{domestic_refuse}) {
            if ($_->{request_containers}[0] eq $CONTAINERS{refuse_180}) {
                $self->{c}->stash->{can_request_larger} = 1;
            }
        }
    }

    return unless $self->{c}->stash->{is_staff};

    my @containers_on_property;

    foreach my $row (@$rows) {
        next unless $row->{request_containers};
        push @containers_on_property, @{$row->{request_containers}};
        $row->{request_allowed} = 1;
        $row->{request_max} = 3;
    }

    my %new_row = (
        service_id => 'other_containers',
        service_name => 'Other containers',
        request_containers => [],
        request_only => 1,
        request_allowed => 1,
        request_max => 3,
    );

    my %all_containers = reverse %{$self->waste_containers};
    foreach my $v (sort { $a cmp $b } keys %all_containers) {
        next if $v =~ /Communal/;
        my $k = $all_containers{$v};
        next if grep { $k == $_ } @containers_on_property;
        push @{$new_row{request_containers}}, $k;
    }

    push @$rows, \%new_row;
}

=head2 waste_munge_request_form_pages

Larger bin request has a separate request flow

=cut

sub waste_munge_request_form_pages {
    my ($self, $page_list, $field_list) = @_;
    my $c = $self->{c};

    if ($c->get_param('exchange')) {
        $c->stash->{first_page} = 'medical_condition';
        $c->stash->{form_class} = "FixMyStreet::App::Form::Waste::Request::Merton::Larger";
    }
}

sub waste_request_form_first_next {
    my $self = shift;
    return sub {
        my $data = shift;
        return 'about_you' if $data->{"container-$CONTAINERS{recycling_blue_stripe_bag}"} || $data->{"container-$CONTAINERS{paper_bag}"} || $data->{"container-$CONTAINERS{recycling_purple_bag}"} || $data->{"container-$CONTAINERS{refuse_red_stripe_bag}"};
        return 'replacement';
    };
}

sub waste_munge_request_form_fields {
    my ($self, $field_list) = @_;

    for (my $i=0; $i<@$field_list; $i+=2) {
        my ($key, $value) = ($field_list->[$i], $field_list->[$i+1]);
        next unless $key =~ /^container-(\d+)/;
        my $id = $1;
        my $cost = $self->request_cost($id);
        if ($cost) {
            my $price = sprintf("£%.2f", $cost / 100);
            $price =~ s/\.00$//;
            $value->{option_hint} = "There is a $price cost for this container";
        }
    }
}

=head2 request_cost

Calculate how much, if anything, a request for a container should be.

=cut

sub request_cost {
    my ($self, $id) = @_;
    my $costs = WasteWorks::Costs->new({ cobrand => $self });
    my $cost = $costs->get_cost('request_cost_' . $id);
    return $cost;
}

sub waste_munge_request_data {
    my ($self, $id, $data, $form) = @_;

    my $c = $self->{c};
    my $address = $c->stash->{property}->{address};
    my $container = $c->stash->{containers}{$id};
    my $quantity = $data->{"quantity-$id"} || 1;
    my $reason = $data->{request_reason} || '';
    my $nice_reason = $c->stash->{label_for_field}->($form, 'request_reason', $reason)
        if $reason;

    my $service_id;
    my $services = $c->stash->{services};
    foreach my $s (keys %$services) {
        my $containers = $services->{$s}{request_containers};
        foreach (@$containers) {
            if ($_ eq $id) {
                if ($s eq 'other_containers') {
                    $service_id = $container_to_service{$id};
                } else {
                    $service_id = $s;
                }
            }
        }
    }
    $c->set_param('service_id', $service_id) if $service_id;

    my ($action_id, $reason_id);
    my $id_to_add = $id;
    my $id_to_remove;
    if ($data->{medical_condition}) { # Filled in the larger form
        $reason = 'change_capacity';
        $action_id = '2::1';
        $reason_id = '9::9'; # Increase capacity
        $id_to_remove = $CONTAINERS{refuse_180};
    } elsif ($reason eq 'damaged') {
        $action_id = '2::1'; # Remove/Deliver
        $reason_id = '4::4' ; # Damaged
        $id_to_remove = $id;
    } elsif ($reason eq 'missing') {
        $action_id = 1; # Deliver
        $reason_id = 1; # Missing
    } elsif ($reason eq 'new_build') {
        $action_id = 1; # Deliver
        $reason_id = 6; # New Property
    } elsif ($reason eq 'more') {
        $action_id = 1; # Deliver
        $reason_id = 9; # Increase capacity
    } elsif ($reason eq 'collect') {
        # Triggered from Garden new/renewal with reduction
        $action_id = 2; # Remove
        $reason_id = 8; # Remove Containers
        $quantity = $data->{"removal-$id"};
        $id_to_remove = $id;
        $id_to_add = undef;
    } else {
        # No reason, must be a bag
        $action_id = 1; # Deliver
        $reason_id = 9; # Increase capacity
        $nice_reason = "Additional bag required";
    }

    if ($reason eq 'damaged' || $reason eq 'missing') {
        $data->{title} = "Request replacement $container";
    } elsif ($reason eq 'change_capacity') {
        $data->{title} = "Request exchange for $container";
    } elsif ($reason eq 'collect') {
        $data->{title} = "Request $container collection";
    } else {
        $data->{title} = "Request new $container";
    }
    $data->{detail} = "Quantity: $quantity\n\n$address";
    $data->{detail} .= "\n\nReason: $nice_reason" if $nice_reason;
    $data->{detail} .= "\n\n1x $container to deliver" if $id_to_add;
    if ($id_to_remove) {
        my $container_removed = $c->stash->{containers}{$id_to_remove};
        $data->{detail} .= "\n\n" . $quantity . "x $container_removed to collect";
        if ($id_to_add && $id_to_add != $id_to_remove) {
            $id_to_add = $id_to_remove . '::' . $id_to_add;
        }
    }
    if ($data->{request_reason_text}) {
        $data->{detail} .= "\n\nAdditional details: " . $data->{request_reason_text};
        $c->set_param('Notes', $data->{request_reason_text});
    }
    $c->set_param('Action', join('::', ($action_id) x $quantity));
    $c->set_param('Reason', join('::', ($reason_id) x $quantity));

    $c->set_param('Container_Type', $id_to_add || $id_to_remove);

    if ($data->{payment}) {
        my $cost = $self->request_cost($id);
        if ($cost) {
            $cost *= $quantity;
        }
        $c->set_param('payment', $cost || undef); # Want to undefine it if free
    }
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
    if ($data->{category} eq 'Bin not returned' || $data->{category} eq 'Lid not closed') {
        $detail .= ($data->{'extra_Notes'} ? $data->{'extra_Notes'} : '') . "\n\n";
    } else {
        foreach (sort grep { /^extra_/ } keys %$data) {
            $detail .= "$data->{$_}\n\n";
        }
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
    $type = 'RNC' if $p->category eq 'Request new container';
    return $self->waste_payment_ref_council_code . "-$type-" . $p->id;
}

sub check_ggw_transfer_applicable {
    my ($self, $old_address) = @_;

    # Check new address doesn't have a ggw subscription
    return { error => 'current' } if $self->garden_current_subscription;

    # Check that the old address has a ggw subscription and it's not
    # in its expiry period
    my $details = $self->look_up_property($old_address);
    my $old_services = $self->{api_serviceunits};

    my ($old_garden) = grep { $_->{ServiceId} eq '409' } @$old_services;
    $old_garden->{transfer_uprn} = $details->{uprn};

    my $servicetask = $self->garden_current_service_from_service_units($old_services);

    return { error => 'no_previous' } unless $servicetask;

    my $subscription_enddate = _parse_schedules($servicetask)->{end_date};
    return { error => 'due_soon' } if ($subscription_enddate && $self->waste_sub_due($subscription_enddate));

    # Some of garden_container_data_extract from SLWP.pm
    my $today = DateTime->now->set_time_zone(FixMyStreet->local_time_zone)->strftime("%F");
    my $old_subscription_bin_data = Integrations::Echo::force_arrayref($servicetask->{ServiceTaskLines}, 'ServiceTaskLine');
    foreach (@$old_subscription_bin_data) {
        my $start_date = construct_bin_date($_->{StartDate})->strftime("%F");
        my $end_date = construct_bin_date($_->{EndDate})->strftime("%F");
        # No start date check as we do want to take the first one we find, even if it is starting in the future
        next if $end_date lt $today;
        $old_garden->{transfer_bin_number} = $_->{ScheduledAssetQuantity};
        $old_garden->{transfer_bin_type} = $_->{AssetTypeId};
    };
    $old_garden->{subscription_enddate} = $subscription_enddate;
    return $old_garden;
}

=head2 Bulky waste collection

Merton has a 6am collection and cut-off for cancellation time.
Everything else is configured in SLWP/Echo.

=cut

sub bulky_collection_time { { hours => 6, minutes => 0 } }
sub bulky_cancellation_cutoff_time { { hours => 6, minutes => 0 } }
sub bulky_allowed_property {
    my ( $self, $property ) = @_;
    return 1 if $self->bulky_enabled && $property->{has_bulky_service};
}
sub bulky_collection_window_days { 28 }

=item bulky_open_overdue

Returns true if the booking is open and after 6pm on the day of the collection.

=cut

sub bulky_open_overdue {
    my ($self, $event) = @_;

    if ($event->{state} eq 'open' && $self->_bulky_collection_overdue($event)) {
        return 1;
    }
}

sub _bulky_collection_overdue {
    my $collection_due_date = $_[1]->{date};
    $collection_due_date->truncate(to => 'day')->set_hour(18);
    my $today = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);
    return $today > $collection_due_date;
}

1;
