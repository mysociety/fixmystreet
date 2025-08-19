package FixMyStreet::Cobrand::Sutton;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use utf8;
use Moo;
with 'FixMyStreet::Roles::Cobrand::Waste',
     'FixMyStreet::Roles::Cobrand::KingstonSutton',
     'FixMyStreet::Roles::Cobrand::SLWP2',
     'FixMyStreet::Roles::Cobrand::SCP';

use Hash::Util qw(lock_hash);

sub council_area_id { return 2498; }
sub council_area { return 'Sutton'; }
sub council_name { return 'Sutton Council'; }
sub council_url { return 'sutton'; }
sub admin_user_domain { 'sutton.gov.uk' }

my %SERVICE_IDS = (
    domestic_refuse => 940, # 4394
    communal_refuse => 943, # 4407
    fas_refuse => 941, # 4395
    domestic_mixed => 944, # 4390
    communal_mixed => 947, # 4397
    fas_mixed => 945, # 4391
    domestic_paper => 948, # 4388
    communal_paper => 951, # 4396
    fas_paper => 949, # 4402
    domestic_food => 954, # 4389
    communal_food => 957, # 4403
    garden => 953, # 4410
    schedule2_refuse => 942, # 4409
    schedule2_mixed => 946, # 4398
    deliver_bags => 961, # 4427 4432
);
lock_hash(%SERVICE_IDS);

my %CONTAINERS = (
    refuse_140 => 1,
    refuse_180 => 2,
    refuse_240 => 3,
    refuse_360 => 4,
    refuse_1100 => 8,
    refuse_bag => 10,
    recycling_box => 12,
    recycling_240 => 15,
    recycling_360 => 16,
    recycling_1100 => 20,
    recycling_blue_bag => 22,
    paper_140 => 26,
    paper_240 => 27,
    paper_360 => 28,
    paper_1100 => 32,
    paper_bag => 34,
    food_indoor => 43,
    food_outdoor => 46,
    food_240 => 51,
    garden_240 => 39,
    garden_140 => 37,
    garden_sack => 36,
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

sub waste_garden_maximum { 5 }

=head2 ggw_immediate_start

Call hook to accept and return the current_bins at the residence
when a request is made for a new ggw subscription.

If it returns a positive the SLWP2 code will start the subscription
immediately.

Otherwise it will set it to 10 days in the future to allow bin delivery.

=cut

sub ggw_immediate_start {
    my ($self, $bins_on_site) = @_;

    return $bins_on_site;
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

around bulky_check_missed_collection => sub {
    my ($orig, $self, $events, $blocked_codes) = @_;

    $self->$orig($events, $blocked_codes);

    # Now check for any old open missed collections that can be escalated

    my $cfg = $self->feature('echo');
    my $service_id = $cfg->{bulky_service_id};
    my $escalations = $events->filter({ event_type => 3134, service => $service_id });

    my $missed = $self->{c}->stash->{bulky_missed};
    foreach my $guid (keys %$missed) {
        my $missed_event = $missed->{$guid}{report_open};
        next unless $missed_event;

        my $open_escalation = 0;
        foreach ($escalations->list) {
            next unless $_->{report};
            my $missed_guid = $_->{report}->get_extra_field_value('missed_guid');
            next unless $missed_guid;
            if ($missed_guid eq $missed_event->{guid}) {
                $missed->{$guid}{escalations}{missed_open} = $_;
                $open_escalation = 1;
            }
        }

        if (
            # And report is closed completed, or open
            (!$missed_event->{closed} || $missed_event->{completed})
            # And no existing escalation since last collection
            && !$open_escalation
        ) {
            my $now = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);
            # And two working days (from 6pm) have passed
            my $wd = FixMyStreet::WorkingDays->new();
            my $start = $wd->add_days($missed_event->{date}, 2)->set_hour(18);
            my $end = $wd->add_days($start, 2);
            if ($now >= $start && $now < $end) {
                $missed->{$guid}{escalations}{missed} = $missed_event;
            }
        }
    }
};

sub munge_bin_services_for_address {
    my ($self, $rows) = @_;

    # Escalations
    foreach (@$rows) {
        $self->_setup_missed_collection_escalations_for_service($_);
        $self->_setup_container_request_escalations_for_service($_);
    }
}

sub _setup_missed_collection_escalations_for_service {
    my ($self, $row) = @_;
    my $events = $row->{events} or return;

    my $c = $self->{c};
    my $property = $c->stash->{property};

    my $missed_event = ($events->filter({ type => 'missed' })->list)[0];
    my $escalation_event = ($events->filter({ event_type => 3134 })->list)[0];
    if (
        # If there's a missed bin report
        $missed_event
        # And report is closed completed, or open
        && (!$missed_event->{closed} || $missed_event->{completed})
        # And the event source is the same as the current property (for communal)
        && ($missed_event->{source} || 0) == $property->{id}
        # And no existing escalation since last collection
        && !$escalation_event
    ) {
        my $now = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);
        # And two working days (from 6pm) have passed
        my $wd = FixMyStreet::WorkingDays->new();
        my $start = $wd->add_days($missed_event->{date}, 2)->set_hour(18);
        # And window is one day (weekly) two WDs (fortnightly)
        my $window = $row->{schedule} =~ /fortnight|every other/ ? 2 : 1;
        my $end = $wd->add_days($start, $window);
        if ($now >= $start && $now < $end) {
            $row->{escalations}{missed} = $missed_event;
        }
    } elsif ($escalation_event) {
        $row->{escalations}{missed_open} = $escalation_event;
    }
}

sub _setup_container_request_escalations_for_service {
    my ($self, $row) = @_;
    my $open_requests = $row->{requests_open};

    # If there are no open container requests, there's nothing for us to do
    return unless scalar keys %$open_requests;

    # We're only expecting one open container request per service
    my $open_request_event = (values %$open_requests)[0];
    my $escalation_events = $row->{all_events}->filter({ event_type => 3141 });
    my $wd = FixMyStreet::WorkingDays->new();

    foreach my $escalation_event ($escalation_events->list) {
        my $escalation_event_report = $escalation_event->{report};
        next unless $escalation_event_report;

        if ($escalation_event_report->get_extra_field_value('container_request_guid') eq $open_request_event->{guid}) {
            $row->{escalations}{container_open} = $escalation_event;
            # We've marked that there is already an escalation event for the container
            # request, so there's nothing left to do
            return;
        }
    }

    # There's an open container request with no matching escalation so
    # we check now to see if it's within the window for an escalation to be raised
    my $now = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);

    my $start_days = 21; # Window starts on the 21st working day after the request was made
    my $window_days = 10; # Window ends a further 10 working days after the start date
    if (FixMyStreet->config('STAGING_SITE') && !FixMyStreet->test_mode) {
        # For staging site testing (but not automated testing) use quicker/smaller windows
        $start_days = 1;
        $window_days = 2;
    }

    my $start = $wd->add_days($open_request_event->{date}, $start_days)->set_hour(0);
    my $end = $wd->add_days($start, $window_days + 1); # Before this

    if ($now >= $start && $now < $end) {
        $row->{escalations}{container} = $open_request_event;
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

    my $container = $unit->{request_containers}[0] || 0;
    my $service_id = $unit->{service_id};
    if ($service_id eq 'bulky') {
        return "$base/bulky-black";
    }

    if ($service_id == $SERVICE_IDS{communal_refuse} && $unit->{schedule} =~ /fortnight|every other/i) {
        # Communal fortnightly is a wheelie bin, not a large bin
        return svg_container_bin('wheelie', '#8B5E3D');
    }

    my $bag_blue_stripe = svg_container_sack('stripe', '#4f4cf0');
    my $bag_red_stripe = svg_container_sack('stripe', '#E83651');
    my $bag_clear = svg_container_sack('normal', '#d8d8d8');
    my $images = {
        $CONTAINERS{recycling_blue_bag} => $bag_blue_stripe,
        $CONTAINERS{paper_bag} => $bag_clear,
        $CONTAINERS{refuse_bag} => $bag_red_stripe,
        $CONTAINERS{food_outdoor} => "$base/caddy-brown-large",

        # Fallback to the service if no container match
        $SERVICE_IDS{domestic_refuse} => svg_container_bin('wheelie', '#8B5E3D'),
        $SERVICE_IDS{domestic_food} => "$base/caddy-brown-large",
        $SERVICE_IDS{domestic_paper} => svg_container_bin('wheelie', '#41B28A'),
        $SERVICE_IDS{domestic_mixed} => "$base/box-green-mix",
        $SERVICE_IDS{fas_refuse} => $bag_red_stripe,
        $SERVICE_IDS{communal_refuse} => svg_container_bin('communal', '#767472', '#333333'),
        $SERVICE_IDS{fas_mixed} => $bag_blue_stripe,
        $SERVICE_IDS{communal_food} => svg_container_bin('wheelie', '#8B5E3D'),
        $SERVICE_IDS{communal_paper} => svg_container_bin("wheelie", '#767472', '#00A6D2', 1),
        $SERVICE_IDS{communal_mixed} => svg_container_bin('communal', '#41B28A'),
        $SERVICE_IDS{fas_paper} => $bag_clear,
    };
    return $images->{$container} || $images->{$service_id};
}

sub waste_containers {
    my $self = shift;
    return {
        $CONTAINERS{refuse_bag} => 'Refuse Red Stripe Bag',
        $CONTAINERS{recycling_blue_bag} => 'Mixed Recycling Blue Striped Bag',
        $CONTAINERS{paper_bag} => 'Paper & Card Recycling Clear Bag',
        $CONTAINERS{refuse_1100} => 'Communal Refuse bin (1100L)',
        $CONTAINERS{recycling_1100} => 'Communal Recycling bin (1100L)',
        $CONTAINERS{food_240} => 'Communal Food bin (240L)',
        $CONTAINERS{recycling_240} => 'Recycling bin (240L)',
        $CONTAINERS{recycling_360} => 'Recycling bin (360L)',
        $CONTAINERS{paper_360} => 'Paper recycling bin (360L)',
        $CONTAINERS{paper_1100} => 'Communal Paper bin (1100L)',
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
        $SERVICE_IDS{domestic_refuse} => 'Non-Recyclable Refuse',
        $SERVICE_IDS{domestic_food} => 'Food Waste',
        $SERVICE_IDS{domestic_paper} => 'Paper & Card',
        $SERVICE_IDS{domestic_mixed} => 'Mixed Recycling (Cans, Plastics & Glass)',
        $SERVICE_IDS{fas_refuse} => 'Non-Recyclable Refuse',
        $SERVICE_IDS{communal_refuse} => 'Non-Recyclable Refuse',
        $SERVICE_IDS{fas_mixed} => 'Mixed Recycling (Cans, Plastics & Glass)',
        $SERVICE_IDS{garden} => 'Garden Waste',
        $SERVICE_IDS{communal_food} => 'Food Waste',
        $SERVICE_IDS{communal_paper} => 'Paper & Card',
        $SERVICE_IDS{communal_mixed} => 'Mixed Recycling',
        $SERVICE_IDS{fas_paper} => 'Paper & Card',
        $SERVICE_IDS{schedule2_mixed} => 'Mixed Recycling (Cans, Plastics & Glass)',
        $SERVICE_IDS{schedule2_refuse} => 'Non-Recyclable Refuse',
        $SERVICE_IDS{deliver_bags} => '',
    );

    return $service_name_override{$service->{ServiceId}} // '';
}

sub _waste_containers_no_request { return {
    $CONTAINERS{refuse_bag} => 1,
    $CONTAINERS{garden_sack} => 1,
} }

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

    my $service_id;
    my $services = $c->stash->{services};
    foreach my $s (keys %$services) {
        my $containers = $services->{$s}{request_containers};
        foreach (@$containers) {
            $service_id = $s if $_ eq $id;
        }
    }
    $c->set_param('service_id', $service_id) if $service_id;

    my ($action_id, $reason_id);
    my $id_to_remove;
    if ($reason eq 'damaged') {
        $action_id = '2::1'; # Remove/Deliver
        $reason_id = '4::4'; # Damaged
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
        $id = undef;
    } elsif ($reason eq 'change_capacity') {
        $action_id = '2::1'; # Remove/Deliver
        if ($id == $CONTAINERS{refuse_140}) {
            $reason_id = '10::10'; # Reduce Capacity
            $id_to_remove = $CONTAINERS{refuse_240};
        } elsif ($id == $CONTAINERS{refuse_240}) {
            if ($c->stash->{quantities}{$CONTAINERS{refuse_360}}) {
                $reason_id = '10::10'; # Reduce Capacity
                $id_to_remove = $CONTAINERS{refuse_360};
            } else {
                $reason_id = '9::9'; # Increase Capacity
                $id_to_remove = $CONTAINERS{refuse_140};
            }
        } elsif ($id == $CONTAINERS{paper_240}) {
            $reason_id = '9::9'; # Increase Capacity
            $id_to_remove = $CONTAINERS{paper_140};
        }
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
    $data->{detail} = $address;
    $data->{detail} .= "\n\nReason: $nice_reason" if $nice_reason;
    $data->{detail} .= "\n\n1x $container to deliver" if $id;
    if ($id_to_remove) {
        my $container_removed = $c->stash->{containers}{$id_to_remove};
        $data->{detail} .= "\n\n" . $quantity . "x $container_removed to collect";
        $id = $id_to_remove . '::' . $id if $id && $id_to_remove != $id;
    }

    $c->set_param('Action', join('::', ($action_id) x $quantity));
    $c->set_param('Reason', join('::', ($reason_id) x $quantity));
    $c->set_param('Container_Type', $id || $id_to_remove);
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

sub waste_munge_enquiry_form_pages {
    my ($self, $pages, $fields) = @_;
    my $c = $self->{c};
    my $category = $c->get_param('category');

    # Add the service to the main fields form page
    $pages->[1]{intro} = 'enquiry-intro.html';
    $pages->[1]{title} = _enquiry_nice_title($category);

    return unless $category eq 'Bin not returned';;

    my $assisted = $c->stash->{assisted_collection};
    if ($assisted) {
        # Add extra first page with extra question
        $c->stash->{first_page} = 'now_returned';
        unshift @$pages, now_returned => {
            fields => [ 'now_returned', 'continue' ],
            intro => 'enquiry-intro.html',
            title => _enquiry_nice_title($category),
            next => 'enquiry',
        };
        push @$fields, now_returned => {
            type => 'Select',
            widget => 'RadioGroup',
            required => 1,
            label => 'Has the container now been returned to the property?',
            options => [
                { label => 'Yes', value => 'Yes' },
                { label => 'No', value => 'No' },
            ],
        };

        # Remove any non-assisted extra notices
        my @new;
        for (my $i=0; $i<@$fields; $i+=2) {
            if ($fields->[$i] !~ /^extra_NotAssisted/) {
                push @new, $fields->[$i], $fields->[$i+1];
            }
        }
        @$fields = @new;
        $pages->[3]{fields} = [ grep { !/^extra_NotAssisted/ } @{$pages->[3]{fields}} ];
        $pages->[3]{update_field_list} = sub {
            my $form = shift;
            my $c = $form->c;
            my $data = $form->saved_data;
            my $returned = $data->{now_returned} || '';
            my $key = $returned eq 'No' ? 'extra_AssistedReturned' : 'extra_AssistedNotReturned';
            return {
                category => { default => $c->get_param('category') },
                service_id => { default => $c->get_param('service_id') },
                $key => { widget => 'Hidden' },
            }
        };
    } else {
        # Remove any assisted extra notices
        my @new;
        for (my $i=0; $i<@$fields; $i+=2) {
            if ($fields->[$i] !~ /^extra_Assisted/) {
                push @new, $fields->[$i], $fields->[$i+1];
            }
        }
        @$fields = @new;
        $pages->[1]{fields} = [ grep { !/^extra_Assisted/ } @{$pages->[1]{fields}} ];
    }
}

sub _enquiry_nice_title {
    my $category = shift;
    if ($category eq 'Bin not returned') {
        $category = 'Wheelie bin, box or caddy not returned correctly after collection';
    } elsif ($category eq 'Waste spillage') {
        $category = 'Spillage during collection';
    } elsif ($category eq 'Complaint against time') {
        $category = 'Issue with collection';
    } elsif ($category eq 'Failure to Deliver Bags/Containers') {
        $category = 'Issue with delivery';
    }
    return $category;
}

sub waste_munge_enquiry_data {
    my ($self, $data) = @_;
    my $c = $self->{c};

    # Escalations have no notes
    $data->{category} = $c->get_param('category') unless $data->{category};
    $data->{service_id} = $c->get_param('service_id') unless $data->{service_id};

    my $address = $c->stash->{property}->{address};

    $data->{title} = _enquiry_nice_title($data->{category});

    my $detail = "";
    if ($data->{category} eq 'Bin not returned') {
        my $assisted = $c->stash->{assisted_collection};
        my $returned = $data->{now_returned} || '';
        if ($assisted && $returned eq 'No') {
           $data->{extra_Notes} = '*** Property is on assisted list ***';
        }
    } elsif ($data->{category} eq 'Waste spillage') {
        $detail = "$data->{extra_Notes}\n\n";
    } elsif ($data->{category} eq 'Complaint against time') {
        my $event_id = $c->get_param('event_id');
        my ($echo, $ww) = split /:/, $event_id;
        $data->{extra_Notes} = "Originally Echo Event #$echo";
        $data->{extra_original_ref} = $ww;
        $data->{extra_missed_guid} = $c->get_param('event_guid');
    } elsif ($data->{category} eq 'Failure to Deliver Bags/Containers') {
        my $event_id = $c->get_param('event_id');
        my ($echo, $guid, $ww) = split /:/, $event_id;
        $data->{extra_Notes} = "Originally Echo Event #$echo";
        $data->{extra_original_ref} = $ww;
        $data->{extra_container_request_guid} = $guid;
    }
    $detail .= $self->service_name_override({ ServiceId => $data->{service_id} }) . "\n\n";
    $detail .= $address;

    $data->{detail} = $detail;
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

sub bulky_location_text_prompt {
    "Please tell us where you will place the items for collection (the bulky waste collection crews are different to the normal round collection crews and will not know any access codes to your property, so please include access codes here if appropriate)";
}

sub bulky_item_notes_field_mandatory { 1 }
sub bulky_show_individual_notes { 1 } # As mandatory, must be shown

1;
