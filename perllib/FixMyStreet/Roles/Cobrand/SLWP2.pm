=head1 NAME

FixMyStreet::Roles::Cobrand::SLWP2 - shared code for Kingston and Sutton WasteWorks, new Echo

=head1 DESCRIPTION

=cut

package FixMyStreet::Roles::Cobrand::SLWP2;

use Moo::Role;
with 'FixMyStreet::Roles::Cobrand::Echo';
with 'FixMyStreet::Roles::Cobrand::BulkyWaste';

use Integrations::Echo;
use Hash::Util qw(lock_hash);
use JSON::MaybeXS;
use LWP::Simple;
use MIME::Base64;
use WasteWorks::Costs;

sub waste_staff_choose_payment_method { 1 }
around waste_cheque_payments => sub {
    my ($orig, $self) = @_;
    return $self->{c}->stash->{staff_payments_allowed};
};

sub waste_event_state_map {
    return {
        New => { New => 'confirmed' },
        Pending => {
            Unallocated => 'investigating',
            #'Allocated to Crew' => 'action scheduled',
            #Accepted => 'action scheduled',
        },
        Closed => {
            Closed => 'fixed - council',
            Completed => 'fixed - council',
            'Not Completed' => 'unable to fix',
            'Partially Completed' => 'closed',
            Rejected => 'closed',
        },
        Cancelled => {
            Cancelled => 'cancelled',
        },
    };
}

my %SERVICE_IDS = (
    kingston => {
        domestic_refuse => 966, # 4394
        communal_refuse => 969, # 4407
        fas_refuse => 967, # 4395
        domestic_mixed => 970, # 4390
        communal_mixed => 973, # 4397
        fas_mixed => 971, # 4391
        domestic_paper => 974, # 4388
        communal_paper => 977, # 4396
        fas_paper => 975, # 4402
        domestic_food => 980, # 4389
        communal_food => 983, # 4403
        garden => 979, # 4410
        bulky => 986, # 4536
        small_items => 978,
        schedule2_refuse => 968, # 4409
        schedule2_mixed => 972, # 4398
    },
    merton => {
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
        bulky => 1089,
        small_items => 1080,
        schedule2_refuse => 1069, # 4409
        schedule2_mixed => 1073, # 4398
    },
    sutton => {
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
        bulky => 960, # 4536
        small_items => 952,
        schedule2_refuse => 942, # 4409
        schedule2_mixed => 946, # 4398
    }
);
lock_hash(%SERVICE_IDS);

my %EVENT_TYPE_IDS = (
    missed => 3145,
    missed_assisted => 3146,
    request => 3129,
    garden_add => 3159,
    garden_amend => 3163,
    bulky => 3130,
    small_items => 3144,
);
lock_hash(%EVENT_TYPE_IDS);

my %CONTAINERS = (
    refuse_140 => 1,
    refuse_180 => 2,
    refuse_240 => 3,
    refuse_360 => 4,
    recycling_box => 12,
    recycling_240 => 15,
    recycling_blue_bag => 22,
    paper_240 => 27,
    paper_140 => 26,
    food_indoor_5 => 43,
    food_indoor_7 => 44,
    food_outdoor => 46,
    garden_240 => 39,
    garden_140 => 37,
    garden_sack => 36,
);
lock_hash(%CONTAINERS);

my %GARDEN_CONTAINER_IDS = (
    bin240 => 1915,
    bin140 => 1914,
    sack => 1928,
    bag => 1910, # Also used in Merton Echo
);
lock_hash(%GARDEN_CONTAINER_IDS);

my %GARDEN_QUANTITIES = (
    sack => 11,
);

sub garden_service_id { $SERVICE_IDS{$_[0]->moniker}{garden} }

sub waste_service_to_containers { () }

sub garden_subscription_event_id { $EVENT_TYPE_IDS{garden_add} }

sub garden_renewal_reduction_sparks_container_removal { 1 }

sub waste_show_garden_modify {
    my ($self, $unit) = @_;
    return 1 if $self->moniker eq 'kingston';
    return $unit->{garden_sacks} ? 0 : 1;
}

sub waste_relevant_serviceunits {
    my ($self, $result) = @_;
    my @rows;
    my $service_ids = $SERVICE_IDS{$self->moniker};
    foreach (@$result) {
        my $servicetask = $self->_get_current_service_task($_) or next;

        $self->{c}->stash->{schedule2_property} = 1 if $_->{ServiceId} == $service_ids->{schedule2_refuse} || $_->{ServiceId} == $service_ids->{schedule2_mixed};

        my $service_name = $self->service_name_override({ ServiceId => $_->{ServiceId} });
        next unless $service_name;

        push @rows, {
            Id => $_->{Id},
            ServiceId => $_->{ServiceId},
            ServiceTask => $servicetask,
            Service => $_,
            Schedules => _parse_schedules($servicetask, 'task'),
        };

        # FD-5992 override
        if ($self->moniker eq 'sutton' && $rows[-1]{Schedules}{description}) {
            $rows[-1]{Schedules}{description} =~ s/^Every [^ ]*$/Weekly/;
            $rows[-1]{Schedules}{description} =~ s/^Every [^ ]* fortnightly/Fortnightly/i;
        }

    }

    # Merton have asked for a specific ordering
    if ($self->moniker eq 'merton') {
        my @order = qw(garden domestic_food communal_food domestic_mixed communal_mixed fas_mixed
            domestic_paper communal_paper fas_paper domestic_refuse communal_refuse fas_refuse);
        my $c = 0;
        my %order = map { $service_ids->{$_} => $c++ } @order;
        @rows = sort { $order{$a->{ServiceId}} <=> $order{$b->{ServiceId}} } @rows;
    }

    return @rows;
}

# Look for flag of assisted collection property (domestic only, so check all entries)
sub _is_assisted {
    my ($result, $service_ids) = @_;
    my $assisted;
    foreach (@$result) {
        my $service_id = $_->{ServiceId};
        return 0 if $service_id == $service_ids->{fas_refuse} || $service_id == $service_ids->{communal_refuse};
        my $data = Integrations::Echo::force_arrayref($_->{Data}, 'ExtensibleDatum');
        foreach (@$data) {
            $assisted = 1 if $_->{DatatypeName} eq "Assisted Collection" && $_->{Value};
        }
    }
    return $assisted;
}

sub waste_extra_service_info_all_results {
    my ($self, $property, $result) = @_;

    my $cfg = $self->feature('echo');
    my $service_ids = $SERVICE_IDS{$self->moniker};

    if (!(@$result && grep { $_->{ServiceId} == $service_ids->{garden} } @$result)) {
        # No garden collection possible
        $self->{c}->stash->{waste_features}->{garden_disabled} = 1;
    }

    if (@$result && $cfg->{bulky_service_id} && grep { $_->{ServiceId} == $cfg->{bulky_service_id} } @$result) {
        $property->{has_bulky_service} = 1;
    }

    if (@$result && grep { $_->{ServiceId} == $service_ids->{small_items} } @$result) {
        $property->{has_small_items_service} = 1;
    }

    $property->{has_no_services} = scalar @$result == 0;
    $self->{c}->stash->{assisted_collection} = _is_assisted($result, $service_ids);
}

sub waste_extra_service_info {
    my ($self, $property, @rows) = @_;
    my $service_ids = $SERVICE_IDS{$self->moniker};

    if ($self->moniker eq 'merton') {
        # Merton lets everyone pick between bins and sacks
        $self->{c}->stash->{slwp_garden_sacks} = 1;
    }

    foreach (@rows) {
        my $service_id = $_->{ServiceId};
        if ($service_id == $service_ids->{fas_refuse}) {
            $self->{c}->stash->{slwp_garden_sacks} = 1;
        } elsif ($service_id == $service_ids->{domestic_refuse}) {
            $property->{domestic_refuse_bin} = 1;
        }
        $self->{c}->stash->{communal_property} = 1 if $service_id == $service_ids->{communal_refuse} || $service_id == $service_ids->{communal_food} || $service_id == $service_ids->{communal_paper} || $service_id == $service_ids->{communal_mixed};

        if ($service_id == $service_ids->{fas_refuse} || $service_id == $service_ids->{fas_mixed}) {
            $self->{c}->stash->{fas_property} = 1;
        }

        my $schedules = $_->{Schedules};
        if ($schedules->{next}{schedule}) {
            my $allocation = $schedules->{next}{schedule}{Allocation};
            my $type = $allocation->{RoundGroupName} || '';
            if ($type eq 'NTE') {
                $self->{c}->stash->{property_time_banded} = 1;
            }
        }
    }
}

sub waste_service_containers {
    my ($self, $service) = @_;
    my $service_id = $service->{ServiceId};
    my $service_ids = $SERVICE_IDS{$self->moniker};

    # Will get garden info later, in garden_container_data_extract
    # (as garden containers held in a totally different place)
    return ([]) if $service_id == $service_ids->{garden};

    # FAS cannot request containers - FD-5401
    return if ($self->moniker eq 'kingston' || $self->moniker eq 'sutton') && $self->{c}->stash->{fas_property};

    my $waste_containers_no_request = $self->_waste_containers_no_request;

    my $unit = $service->{Service};
    my $service_name = $self->service_name_override($service);
    my $schedules = $service->{Schedules};

    my $data = Integrations::Echo::force_arrayref($unit->{Data}, 'ExtensibleDatum');
    my ($containers, $request_max);
    foreach (@$data) {
        next if $service_id == $service_ids->{communal_refuse} || $service_id == $service_ids->{communal_food} || $service_id == $service_ids->{communal_paper} || $service_id == $service_ids->{communal_mixed};
        my $moredata = Integrations::Echo::force_arrayref($_->{ChildData}, 'ExtensibleDatum');
        my ($container, $quantity) = (0, 0);
        foreach (@$moredata) {
            $container = $_->{Value} if $_->{DatatypeName} eq 'Container Type';
            $quantity = $_->{Value} if $_->{DatatypeName} eq 'Container Quantity';
        }


        if ($container && $quantity) {
            push @$containers, $container;

            $self->{c}->stash->{quantities}->{$container} = $quantity;

            if ($waste_containers_no_request->{$container}) {
                $request_max->{$container} = 0; # Cannot request these
            } elsif ($container == $CONTAINERS{recycling_blue_bag} && $schedules->{description} !~ /fortnight|every other/i) {
                # Blue stripe bag on a weekly collection
                $request_max->{$container} = 0; # Cannot request these
            } elsif ($self->moniker eq 'kingston') {
                if ($container == $CONTAINERS{food_outdoor} || $container == $CONTAINERS{paper_240} || $container == $CONTAINERS{recycling_240}) {
                    $request_max->{$container} = 3;
                } elsif ($container == $CONTAINERS{recycling_box}) {
                    $request_max->{$container} = 5;
                } else {
                    $request_max->{$container} = 1;
                }
            } else {
                # The most you can request is one
                $request_max->{$container} = 1;
            }

            if ($self->moniker eq 'sutton') {
                if ($container == $CONTAINERS{refuse_140} || $container == $CONTAINERS{refuse_360}) {
                    push @$containers, $CONTAINERS{refuse_240};
                    $request_max->{$CONTAINERS{refuse_240}} = 1;
                } elsif ($container == $CONTAINERS{refuse_240}) {
                    push @$containers, $CONTAINERS{refuse_140};
                    $request_max->{$CONTAINERS{refuse_140}} = 1;
                } elsif ($container == $CONTAINERS{paper_140}) {
                    $request_max->{$CONTAINERS{paper_240}} = 1;
                    # Swap 140 for 240 in container list
                    @$containers = map { $_ == $CONTAINERS{paper_140} ? $CONTAINERS{paper_240} : $_ } @$containers;
                }
            }
        }
    }

    my $food_indoor_key = $self->moniker eq 'merton' ? 'food_indoor_7' : 'food_indoor_5';
    if ($service_name =~ /Food/ && !$self->{c}->stash->{quantities}->{$CONTAINERS{$food_indoor_key}}) {
        # Can always request a food caddy
        push @$containers, $CONTAINERS{$food_indoor_key}; # Food waste bin (kitchen)
        $request_max->{$CONTAINERS{$food_indoor_key}} = 1;
    }
    if ($self->moniker eq 'kingston' && grep { $_ == $CONTAINERS{recycling_box} } @$containers) {
        # Can request a bin if you have a box
        push @$containers, $CONTAINERS{recycling_240};
        $request_max->{$CONTAINERS{recycling_240}} = 3;
    }

    return ($containers, $request_max);
}

sub missed_event_types { return {
    $EVENT_TYPE_IDS{request} => 'request',
    $EVENT_TYPE_IDS{missed} => 'missed',
    $EVENT_TYPE_IDS{missed_assisted} => 'missed',
    $EVENT_TYPE_IDS{bulky} => 'bulky',
    $EVENT_TYPE_IDS{small_items} => 'small_items',
} }

sub waste_munge_report_data {
    my ($self, $id, $data) = @_;

    my $c = $self->{c};

    my $address = $c->stash->{property}->{address};
    my $cfg = $self->feature('echo');
    my $service = $c->stash->{services}{$id}{service_name};
    if (   $cfg->{bulky_service_id}
        && $id == $cfg->{bulky_service_id} )
    {
        $service = 'bulky collection';
    }
    if (   $cfg->{small_items_service_id}
        && $id == $cfg->{small_items_service_id} )
    {
        $service = 'small items collection';
    }
    if ($c->get_param('additional') && $c->stash->{is_staff}) {
        $data->{category} = 'Request additional collection';
        $data->{title} = "Request additional $service collection";
    } else {
        my $service_ids = $SERVICE_IDS{$self->moniker};
        my %lookup = reverse %$service_ids;
        my %assisted = map { $_ => 1 } qw(domestic_refuse domestic_mixed domestic_paper domestic_food garden small_items);
        if ($c->stash->{assisted_collection} && $assisted{$lookup{$id}}) {
            $data->{category} = 'Report missed assisted collection';
        } else {
            # Reset in case more than one service being reported at once
            $data->{category} = 'Report missed collection';
        }
        $data->{title} = "Report missed $service";
    }
    $data->{detail} = "$data->{title}\n\n$address";
    if ( my $booking_report = $c->stash->{original_booking_report} ) {
        $c->set_param('Exact_Location', $booking_report->get_extra_field_value('Exact_Location'));
        $c->set_param('Original_Event_ID', $booking_report->external_id);
    }
    $c->set_param('Notes', $data->{extra_detail}) if $data->{extra_detail};
    $c->set_param('service_id', $id);
}

# Garden waste

sub garden_service_name { 'garden waste collection service' }
sub garden_echo_container_name { 'Container Details' } # Not actually used, TODO refactor

# Loop through task lines, may be more than one.
# Have to pass end date in because we're currently creating the services stash
sub garden_container_data_extract {
    my ($self, $data, $containers, $quantities, $schedules) = @_;
    my $costs = WasteWorks::Costs->new({ cobrand => $self });

    my $today = DateTime->now->set_time_zone(FixMyStreet->local_time_zone)->strftime("%F");
    my ($garden_bins, $garden_sacks, $garden_cost, $garden_container, $container_end_date);
    foreach (@$data) {
        my $start_date = construct_bin_date($_->{StartDate})->strftime("%F");
        my $end_date = construct_bin_date($_->{EndDate})->strftime("%F");
        # No start date check as we do want to take the first one we find, even if it is starting in the future
        next if $end_date lt $today;
        $container_end_date = $end_date if $end_date lt $schedules->{end_date};
        my $asset_id = $_->{AssetTypeId};
        if ($asset_id == $GARDEN_CONTAINER_IDS{sack} || $asset_id == $GARDEN_CONTAINER_IDS{bag}) {
            $garden_sacks = 1;
            $garden_bins = undef;
            $garden_cost += $costs->sacks_renewal(1, $schedules->{end_date}) / 100;
            $garden_container = $CONTAINERS{garden_sack};
        } else {
            $garden_sacks = 0;
            $garden_bins += $_->{ScheduledAssetQuantity};
            $garden_cost += $costs->bins_renewal($garden_bins, $schedules->{end_date}) / 100;
            $garden_container = $asset_id == $GARDEN_CONTAINER_IDS{bin140} ? $CONTAINERS{garden_140} : $CONTAINERS{garden_240};
        }
        last;
    }
    push @$containers, $garden_container;
    $quantities->{$garden_container} = $garden_bins;
    return ($garden_bins, $garden_sacks, $garden_cost, $garden_container, $container_end_date);
}

# We don't have overdue renewals here
sub waste_sub_overdue { 0 }

sub alternative_backend_field_names {
    my ($self, $field) = @_;
    my %alternative_name = (
        'Subscription_End_Date' => 'End_Date',
    );
    return $alternative_name{$field};
}

sub waste_garden_sub_params {
    my ($self, $data, $type) = @_;
    $type ||= '';
    my $c = $self->{c};

    my $service = $self->garden_current_subscription;
    my $choice = $data->{container_choice} || '';
    my $existing = $service ? $service->{garden_container} : undef;
    my ($container);
    if ($data->{transfer_bin_type}) {
        $container = $data->{transfer_bin_type};
    } elsif ($choice) {
        $choice = 'bin240' if $choice eq 'bin';
        $container = $GARDEN_CONTAINER_IDS{$choice};
    } elsif ($existing) {
        my $key = {
            $CONTAINERS{garden_sack} => 'sack',
            $CONTAINERS{garden_140} => 'bin140',
            $CONTAINERS{garden_240} => 'bin240',
        }->{$existing};
        $container = $GARDEN_CONTAINER_IDS{$key};
    }
    $container ||= $GARDEN_CONTAINER_IDS{bin240};

    $c->set_param('Paid_Container_Type', $container);
    if ($container == $GARDEN_CONTAINER_IDS{sack}) {
        $c->set_param('Paid_Container_Quantity', $GARDEN_QUANTITIES{sack});
    } elsif ($data->{bins_wanted}) {
        $c->set_param('Paid_Container_Quantity', $data->{bins_wanted});
    }

    if ( $data->{new_bins} && $data->{new_bins} > 0) {
        $c->set_param('Container_Type', $container);
        if ($container == $GARDEN_CONTAINER_IDS{sack}) {
            $c->set_param('Quantity', $GARDEN_QUANTITIES{sack});
        } else {
            my $num = abs($data->{new_bins});
            $c->set_param('Quantity', $num);
        }
    }

    if ($type eq $c->cobrand->waste_subscription_types->{New}) {
        my $now = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);
        my $add_days = $self->call_hook(garden_subscription_start_days => $data) // 10;
        $c->set_param('Start_Date', $now->add(days => $add_days)->dmy('/'));
        $c->set_param('End_Date', $now->add(years => 1)->subtract(days => 1)->dmy('/'));
    } elsif ($type eq $c->cobrand->waste_subscription_types->{Renew}) {
        my $sub_end = DateTime::Format::W3CDTF->parse_datetime($service->{end_date})->truncate( to => 'day' );
        $c->set_param('Start_Date', $sub_end->add(days => 1)->dmy('/'));
        $c->set_param('End_Date', $sub_end->add(years => 1)->subtract(days => 1)->dmy('/'));
    }
}

sub waste_garden_mod_params {
    my ($self, $data) = @_;
    my $c = $self->{c};

    my $service = $self->garden_current_subscription;
    my $existing = $service->{garden_container};
    if ($existing != $CONTAINERS{garden_sack}) {
        $data->{category} = 'Amend Garden Subscription';
        my $key = {
            $CONTAINERS{garden_140} => 'bin140',
            $CONTAINERS{garden_240} => 'bin240',
        }->{$existing};
        my $container = $GARDEN_CONTAINER_IDS{$key};

        $c->set_param('Additional_Collection_Container_Type', $container);
        $c->set_param('Additional_Container_Quantity', $data->{new_bins});
        $c->set_param('Container_Ordered_Type', $container);
        $c->set_param('Container_Ordered_Quantity', $data->{new_bins});
    }
}

sub waste_garden_subscribe_form_setup {
    my ($self) = @_;
    my $c = $self->{c};
    if ($c->stash->{slwp_garden_sacks}) {
        $c->stash->{form_class} = 'FixMyStreet::App::Form::Waste::Garden::Sacks';
    }
}

sub waste_garden_renew_form_setup {
    my ($self) = @_;
    my $c = $self->{c};
    if ($c->stash->{slwp_garden_sacks}) {
        $c->stash->{form_class} = 'FixMyStreet::App::Form::Waste::Garden::Sacks::Renew';
        my $service = $c->cobrand->garden_current_subscription;
        if ($self->moniker eq 'merton') {
            if ($service->{garden_container} == $CONTAINERS{garden_sack}) {
                $c->stash->{first_page} = 'sacks_details';
            }
            # Else default to 'intro' from the main code
        } else {
            $c->stash->{first_page} = 'sacks_choice';
        }
    }
}

=item * When a garden subscription is sent to Echo, we include payment details

=cut

sub open311_extra_data_include {
    my ($self, $row, $h) = @_;

    my $open311_only = [
        #{ name => 'email', value => $row->user->email }
    ];

    if ( $row->category eq 'Garden Subscription' ) {
        if ( $row->get_extra_metadata('contributed_as') && $row->get_extra_metadata('contributed_as') eq 'anonymous_user' ) {
            push @$open311_only, { name => 'contributed_as', value => 'anonymous_user' };
        }

        my $ref = $row->get_extra_metadata('payment_reference');
        push @$open311_only, { name => 'Transaction_Number', value => $ref } if $ref;

        my $payment = $row->get_extra_field_value('pro_rata') || $row->get_extra_field_value('payment');
        my $admin_fee = $row->get_extra_field_value('admin_fee');
        $payment += $admin_fee if $admin_fee;
        if ($payment) {
            my $amount = sprintf( '%.2f', $payment / 100 );
            push @$open311_only, { name => 'Payment_Amount', value => $amount };
        }
    }

    return $open311_only;
}

=item * If Echo errors, we try and deal with standard issues - a renewal on an expired subscription, or a duplicate event

=cut

sub open311_post_send {
    my ($self, $row, $h, $sender) = @_;
    my $error = $sender->error;
    my $db = FixMyStreet::DB->schema->storage;
    $db->txn_do(sub {
        my $row2 = FixMyStreet::DB->resultset('Problem')->search({ id => $row->id }, { for => \'UPDATE' })->single;
        if ($error =~ /Cannot renew this property, a new request is required/ && $row2->title eq "Garden Subscription - Renew") {
            # Was created as a renewal, but due to DD delay has now expired. Switch to new subscription
            $row2->title("Garden Subscription - New");
            $row2->update_extra_field({ name => "Request_Type", value => $self->waste_subscription_types->{New} });
            $row2->update;
            $row->discard_changes;
        } elsif ($error =~ /Missed Collection event already open for the property/) {
            $row2->state('duplicate');
            $row2->update;
            $row->discard_changes;
        } elsif ($error =~ /Selected reservations expired|Invalid reservation reference/) {
            $self->bulky_refetch_slots($row2);
            $row->discard_changes;
        } elsif ($error =~ /Duplicate Event! Original eventID: (\d+)/) {
            my $id = $1;
            my $cfg = $self->feature('echo');
            my $echo = Integrations::Echo->new(%$cfg);
            my $event = $echo->GetEvent($id, 'Id');
            $row2->external_id($event->{Guid});
            $sender->success(1);
            $row2->update;
            $row->discard_changes;
        }
    });
}

=item * Look for completion photos on updates, and ignore "Not Completed" without a resolution code

=cut

sub open311_waste_update_extra {
    my ($self, $cfg, $event) = @_;

    # Could have got here with a full event (pull) or subset (push)
    if (!$event->{Data}) {
        $event = $cfg->{echo}->GetEvent($event->{Guid});
    }
    my $data = Integrations::Echo::force_arrayref($event->{Data}, 'ExtensibleDatum');
    my @media;
    foreach (@$data) {
        if ($_->{DatatypeName} eq 'Post Collection Photo' || $_->{DatatypeName} eq 'Pre Collection Photo') {
            my $value = decode_base64($_->{Value});
            my $type = FixMyStreet::PhotoStorage->detect_type($value);
            push @media, "data:image/$type,$value";
        }
    }

    my $override_status;
    my $event_type = $cfg->{event_types}{$event->{EventTypeId}};
    my $state_id = $event->{EventStateId};
    my $resolution_id = $event->{ResolutionCodeId} || '';
    my $description = $event_type->{states}{$state_id}{name} || '';
    if ($description eq 'Not Completed' && !$resolution_id) {
        $override_status = "";
    }

    return (
        @media ? ( media_url => \@media ) : (),
        defined $override_status ? (status => $override_status ) : (),
    );
}

=head2 Bulky waste collection

SLWP looks 8 weeks ahead for collection dates, and cancels by sending an
update, not a new report. It sends the event to the backend before collecting
payment, and does not refund on cancellations. It has a hard-coded list of
property types allowed to book collections.

=cut

sub waste_bulky_missed_blocked_codes {
    return {
        # Partially completed
        12399 => {
            507 => 'Not all items presented',
            380 => 'Some items too heavy',
        },
        # Completed
        12400 => {
            606 => 'More items presented than booked',
        },
        # Not Completed
        12401 => {
            460 => 'Nothing out',
            379 => 'Item not as described',
            100 => 'No access',
            212 => 'Too heavy',
            473 => 'Damage on site',
            234 => 'Hazardous waste',
        },
    };
}

sub bulky_collection_window_days { 56 }

sub bulky_cancel_by_update { 1 }
sub bulky_send_before_payment { 1 }
sub bulky_show_location_field_mandatory { 1 }

sub bulky_can_refund { 0 }

sub collection_date {
    my ($self, $p) = @_;
    return $self->_bulky_date_to_dt($p->get_extra_field_value('Collection_Date_-_Bulky_Items') || $p->get_extra_field_value('Collection_Date'));
}

sub bulky_free_collection_available { 0 }

sub bulky_hide_later_dates { 1 }

=head2 Sending to Echo

We use the reserved slot GUID and reference,
and the provided date/location information.
Items are sent through with their notes as individual entries

=cut

sub waste_munge_bulky_data {
    my ($self, $data) = @_;

    my $c = $self->{c};

    my $fields = $c->stash->{small_items} ?
      {
        title => 'Small items collection',
        category => 'Small items collection',
        date_field => 'extra_Collection_Date_-_Bulky_Items', # Only used on FMS side so left as is
        description_field => '',
        ids_field => 'extra_Small_Item_Type',
      }
      :
      {
        title => 'Bulky goods collection',
        category => 'Bulky collection',
        date_field => 'extra_Collection_Date_-_Bulky_Items',
        description_field => 'extra_TEM_-_Bulky_Collection_Description',
        ids_field => 'extra_TEM_-_Bulky_Collection_Item',
      };

    my ($date, $ref, $expiry) = split(";", $data->{chosen_date});

    my $guid_key = $c->stash->{booking_class}->guid_key;
    $data->{extra_GUID} = $c->waste_cache_get($guid_key);
    $data->{extra_reservation} = $ref;

    $data->{title} = $fields->{title};
    $data->{detail} = "Address: " . $c->stash->{property}->{address};
    $data->{category} = $fields->{category};
    $data->{ $fields->{date_field} } = $date;
    $data->{extra_Exact_Location} = $data->{location};

    my $first_date = $c->session->{first_date_returned};
    $first_date = DateTime::Format::W3CDTF->parse_datetime($first_date);
    my $dt = DateTime::Format::W3CDTF->parse_datetime($date);
    $data->{'extra_First_Date_Offered_-_Bulky'} = $first_date->strftime("%d/%m/%Y");

    my @items_list = $c->stash->{small_items} ? @{ $self->small_items_master_list } : @{ $self->bulky_items_master_list };
    my %items = map { $_->{name} => $_->{bartec_id} } @items_list;

    my @notes;
    my @ids;
    my @photos;
    my %types;

    my $max = $c->stash->{booking_maximum};
    for (1..$max) {
        if (my $item = $data->{"item_$_"}) {
            push @notes, $data->{"item_notes_$_"} || '';
            push @ids, $items{$item};
            push @photos, $data->{"item_photos_$_"} || '';
            $types{$item}++;
        };
    }
    $data->{ $fields->{description_field} } = join("::", @notes) if $fields->{description_field};
    $data->{ $fields->{ids_field} } = join("::", @ids);
    $data->{extra_Image} = join("::", @photos);

    if ($c->stash->{small_items}) {
        $data->{extra_Notes} = join("\n", map { "$types{$_} x $_" } sort keys %types);
    }

    $self->bulky_total_cost($data);
}

sub waste_reconstruct_bulky_data {
    my ($self, $p) = @_;

    my $saved_data = {
        "chosen_date" => $p->get_extra_field_value('Collection_Date_-_Bulky_Items') || $p->get_extra_field_value('Collection_Date'),
        "location" => $p->get_extra_field_value('Exact_Location'),
        "location_photo" => $p->get_extra_metadata("location_photo"),
    };

    my @fields = split /::/,
        $p->get_extra_field_value('TEM_-_Bulky_Collection_Item')
        || $p->get_extra_field_value('Bulky_Collection_Bulky_Items')
        || $p->get_extra_field_value('Small_Item_Type');
    my @notes = split /::/,
        $p->get_extra_field_value('TEM_-_Bulky_Collection_Description')
        || $p->get_extra_field_value('Bulky_Collection_Notes')
        || '';

    for my $id (1..@fields) {
        $saved_data->{"item_$id"} = $p->get_extra_metadata("item_$id");
        $saved_data->{"item_notes_$id"} = $notes[$id-1];
        $saved_data->{"item_photo_$id"} = $p->get_extra_metadata("item_photo_$id");
    }

    $saved_data->{name} = $p->name;
    $saved_data->{email} = $p->user->email;
    $saved_data->{phone} = $p->phone_waste;

    return $saved_data;
}

=head2 suppress_report_sent_email

For Bulky Waste reports, we want to send the email after payment has been confirmed, so we
suppress the email here.

=cut

sub suppress_report_sent_email {
    my ($self, $report) = @_;

    if ($report->cobrand_data eq 'waste' && $report->category eq 'Bulky collection') {
        return 1;
    }

    return 0;
}

sub bulky_location_photo_prompt {
    'Help us by attaching a photo of where the items will be left for collection.';
}

1;
