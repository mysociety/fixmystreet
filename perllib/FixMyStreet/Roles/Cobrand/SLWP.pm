=head1 NAME

FixMyStreet::Roles::Cobrand::SLWP - shared code for anything with the SLWP Echo

=head1 DESCRIPTION

=cut

package FixMyStreet::Roles::Cobrand::SLWP;

use Moo::Role;
with 'FixMyStreet::Roles::Cobrand::Echo';
with 'FixMyStreet::Roles::Cobrand::BulkyWaste';

use Integrations::Echo;
use JSON::MaybeXS;
use LWP::Simple;
use MIME::Base64;

around look_up_property => sub {
    my ($orig, $self, $id) = @_;
    my $data = $orig->($self, $id);

    my $cfg = $self->feature('echo');
    if ($cfg->{nlpg} && $data->{uprn}) {
        my $uprn_data = get(sprintf($cfg->{nlpg}, $data->{uprn}));
        $uprn_data = JSON::MaybeXS->new->decode($uprn_data) if $uprn_data;
        if (!$uprn_data || $uprn_data->{results}[0]{LPI}{LOCAL_CUSTODIAN_CODE_DESCRIPTION} ne $self->lpi_value) {
            $self->{c}->stash->{template} = 'waste/missing.html';
            $self->{c}->detach;
        }
    }
    return $data;
};

sub waste_staff_choose_payment_method { 1 }
sub waste_cheque_payments { shift->{c}->stash->{staff_payments_allowed} }

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

use constant CONTAINER_REFUSE_140 => 1;
use constant CONTAINER_REFUSE_240 => 2;
use constant CONTAINER_REFUSE_360 => 3;
use constant CONTAINER_REFUSE_BLUE_BAG => 4;
use constant CONTAINER_RECYCLING_BIN => 12;
use constant CONTAINER_RECYCLING_BOX => 16;
use constant CONTAINER_RECYCLING_PURPLE_BAG => 17;
use constant CONTAINER_RECYCLING_BLUE_BAG => 18;
use constant CONTAINER_PAPER_BIN => 19;
use constant CONTAINER_FOOD_INDOOR => 23;
use constant CONTAINER_FOOD_OUTDOOR => 24;
use constant CONTAINER_PAPER_BIN_140 => 36;
use constant CONTAINER_GARDEN_BIN => 26;
use constant CONTAINER_GARDEN_BIN_140 => 27;
use constant CONTAINER_GARDEN_SACK => 28;

sub garden_service_id { 2247 }

sub waste_service_to_containers { () }

sub garden_subscription_event_id { 1638 }

sub waste_show_garden_modify {
    my ($self, $unit) = @_;
    return 1 if $self->moniker eq 'kingston';
    return $unit->{garden_sacks} ? 0 : 1;
}

sub waste_relevant_serviceunits {
    my ($self, $result) = @_;
    my @rows;
    foreach (@$result) {
        my $servicetasks = $self->_get_service_tasks($_);
        foreach my $task (@$servicetasks) {
            my $service_id = $task->{TaskTypeId};

            # Sneak this in here before it's ignored for not having a service name
            $self->{c}->stash->{schedule2_property} = 1 if $service_id == 3576 || $service_id == 3571 || $service_id == 4004;

            my $service_name = $self->service_name_override({ ServiceId => $service_id });
            next unless $service_name;

            my $schedules = _parse_schedules($task, 'task');

            # Ignore retired diesel rounds
            next if $self->moniker eq 'kingston' && !$schedules->{next} && $service_id != $self->garden_service_id;

            push @rows, {
                Id => $_->{Id},
                ServiceId => $task->{TaskTypeId},
                ServiceTask => $task,
                Schedules => $schedules,
            };
        }
    }
    return @rows;
}

sub waste_extra_service_info_all_results {
    my ($self, $property, $result) = @_;

    my $cfg = $self->feature('echo');

    if (!(@$result && grep { $_->{ServiceId} == 409 } @$result)) {
        # No garden collection possible
        $self->{c}->stash->{waste_features}->{garden_disabled} = 1;
    }

    if ($self->moniker eq 'merton' && @$result == 1 && $result->[0]{ServiceId} == 409) {
        # No garden collection possible, if only service is garden
        $self->{c}->stash->{waste_features}->{garden_disabled} = 1;
    }

    if (@$result && $cfg->{bulky_service_id} && grep { $_->{ServiceId} == $cfg->{bulky_service_id} } @$result) {
        $property->{has_bulky_service} = 1;
    }

    $property->{has_no_services} = scalar @$result == 0;

    foreach (@$result) {
        my $data = Integrations::Echo::force_arrayref($_->{Data}, 'ExtensibleDatum');
        foreach (@$data) {
            $self->{c}->stash->{assisted_collection} = 1 if $_->{DatatypeName} eq "Assisted Collection" && $_->{Value};
        }
    }
}

sub waste_extra_service_info {
    my ($self, $property, @rows) = @_;

    if ($self->moniker eq 'merton') {
        # Merton lets everyone pick between bins and sacks
        $self->{c}->stash->{slwp_garden_sacks} = 1;
    }

    foreach (@rows) {
        my $service_id = $_->{ServiceId};
        if ($service_id == 2242) { # Collect Domestic Refuse Bag
            $self->{c}->stash->{slwp_garden_sacks} = 1;
        } elsif ($service_id == 2238) { # Collect Domestic Refuse Bin
            $property->{domestic_refuse_bin} = 1;
        }
        $self->{c}->stash->{communal_property} = 1 if $service_id == 2243 || $service_id == 2248 || $service_id == 2249 || $service_id == 2250; # Communal
    }
}

sub waste_service_containers {
    my ($self, $service) = @_;

    my $waste_containers_no_request = $self->_waste_containers_no_request;

    my $task = $service->{ServiceTask};
    my $service_id = $service->{ServiceId};
    my $service_name = $self->service_name_override($service);
    my $schedules = $service->{Schedules};

    my $data = Integrations::Echo::force_arrayref($task->{Data}, 'ExtensibleDatum');
    my ($containers, $request_max);
    foreach (@$data) {
        next if $service_id == 2243 || $service_id == 2248 || $service_id == 2249 || $service_id == 2250; # Communal
        my $moredata = Integrations::Echo::force_arrayref($_->{ChildData}, 'ExtensibleDatum');
        my ($container, $quantity) = (0, 0);
        foreach (@$moredata) {
            $container = $_->{Value} if $_->{DatatypeName} eq 'Container Type' || $_->{DatatypeName} eq 'Container';
            $quantity = $_->{Value} if $_->{DatatypeName} eq 'Quantity';
        }

        next if $waste_containers_no_request->{$container};

        next if $container == CONTAINER_RECYCLING_BLUE_BAG && $schedules->{description} !~ /fortnight/; # Blue stripe bag on a weekly collection

        if ($container && $quantity) {
            $self->{c}->stash->{property_time_banded} = 1 if $container == CONTAINER_RECYCLING_PURPLE_BAG;

            push @$containers, $container;
            next if $container == CONTAINER_GARDEN_SACK; # Garden waste bag

            $self->{c}->stash->{quantities}->{$container} = $quantity;

            if ($self->moniker eq 'kingston') {
                if ($container == CONTAINER_FOOD_OUTDOOR || $container == CONTAINER_PAPER_BIN || $container == CONTAINER_RECYCLING_BIN) {
                    $request_max->{$container} = 3;
                } elsif ($container == CONTAINER_RECYCLING_BOX) {
                    $request_max->{$container} = 5;
                } else {
                    $request_max->{$container} = 1;
                }
            } else {
                # The most you can request is one
                $request_max->{$container} = 1;
            }

            if ($self->moniker eq 'sutton') {
                if ($container == CONTAINER_REFUSE_140 || $container == CONTAINER_REFUSE_360) {
                    push @$containers, CONTAINER_REFUSE_240;
                    $request_max->{+CONTAINER_REFUSE_240} = 1;
                } elsif ($container == CONTAINER_REFUSE_240) {
                    push @$containers, CONTAINER_REFUSE_140;
                    $request_max->{+CONTAINER_REFUSE_140} = 1;
                } elsif ($container == CONTAINER_PAPER_BIN_140) {
                    $request_max->{+CONTAINER_PAPER_BIN} = 1;
                    # Swap 140 for 240 in container list
                    @$containers = map { $_ == CONTAINER_PAPER_BIN_140 ? CONTAINER_PAPER_BIN : $_ } @$containers;
                }
            }
        }
    }

    if ($service_name =~ /Food/ && !$self->{c}->stash->{quantities}->{+CONTAINER_FOOD_INDOOR}) {
        # Can always request a food caddy
        push @$containers, CONTAINER_FOOD_INDOOR; # Food waste bin (kitchen)
        $request_max->{+CONTAINER_FOOD_INDOOR} = 1;
    }
    if ($self->moniker eq 'kingston' && grep { $_ == CONTAINER_RECYCLING_BOX } @$containers) {
        # Can request a bin if you have a box
        push @$containers, CONTAINER_RECYCLING_BIN;
        $request_max->{+CONTAINER_RECYCLING_BIN} = 3;
    }

    return ($containers, $request_max);
}

sub missed_event_types { {
    1635 => 'request',
    1566 => 'missed',
    1568 => 'missed',
    1571 => 'missed',
    1636 => 'bulky',
} }

sub parse_event_missed {
    my ($self, $echo_event, $closed, $events) = @_;
    my $report = $self->problems->search({ external_id => $echo_event->{Guid} })->first;
    my $event = {
        closed => $closed,
        date => construct_bin_date($echo_event->{EventDate}),
    };
    $event->{report} = $report if $report;

    my $service_id = $echo_event->{ServiceId};
    if ($service_id == 405) {
        push @{$events->{missed}->{2238}}, $event;
        push @{$events->{missed}->{2242}}, $event;
        push @{$events->{missed}->{3576}}, $event;
    } elsif ($service_id == 406) {
        push @{$events->{missed}->{2243}}, $event;
    } elsif ($service_id == 409) {
        push @{$events->{missed}->{2247}}, $event;
    } elsif ($service_id == 420) { # TODO Will food events come in as this?
        push @{$events->{missed}->{2239}}, $event;
        push @{$events->{missed}->{2248}}, $event;
    } elsif ($service_id == 413) {
        push @{$events->{missed}->{413}}, $event;
    } elsif ($service_id == 408 || $service_id == 410) {
        my $data = Integrations::Echo::force_arrayref($echo_event->{Data}, 'ExtensibleDatum');
        foreach (@$data) {
            if ($_->{DatatypeName} eq 'Paper' && $_->{Value} == 1) {
                push @{$events->{missed}->{2240}}, $event;
                push @{$events->{missed}->{2249}}, $event;
                push @{$events->{missed}->{2632}}, $event;
            } elsif ($_->{DatatypeName} eq 'Container Mix' && $_->{Value} == 1) {
                push @{$events->{missed}->{2241}}, $event;
                push @{$events->{missed}->{2246}}, $event;
                push @{$events->{missed}->{2250}}, $event;
                push @{$events->{missed}->{3571}}, $event;
            } elsif ($_->{DatatypeName} eq 'Food' && $_->{Value} == 1) {
                push @{$events->{missed}->{2239}}, $event;
                push @{$events->{missed}->{2248}}, $event;
            }
        }
    } else {
        push @{$events->{missed}->{$service_id}}, $event;
    }
}

sub waste_munge_report_data {
    my ($self, $id, $data) = @_;

    my $c = $self->{c};

    my $booking_report;
    if ($c->get_param('original_booking_id')) {
        $booking_report = FixMyStreet::DB->resultset("Problem")->find({ id => $c->get_param('original_booking_id') });
    };
    my $address = $c->stash->{property}->{address};
    my $cfg = $self->feature('echo');
    my $service = $c->stash->{services}{$id}{service_name};
    if ($id == $cfg->{bulky_service_id}) {
        $service = 'bulky collection';
    }
    if ($c->get_param('additional') && $c->stash->{is_staff}) {
        $data->{category} = 'Request additional collection';
        $data->{title} = "Request additional $service collection";
    } else {
        $data->{title} = "Report missed $service";
    }
    $data->{detail} = "$data->{title}\n\n$address";
    if ($booking_report) {
        $c->set_param('Exact_Location', $booking_report->get_extra_field_value('Exact_Location'));
        $c->set_param('Original_Event_ID', $booking_report->external_id);
    }
    $c->set_param('Notes', $data->{extra_detail}) if $data->{extra_detail};
    $c->set_param('service_id', $id);
}

# Garden waste

sub garden_service_name { 'garden waste collection service' }
sub garden_echo_container_name { 'SLWP - Containers' }

sub garden_subscription_email_renew_reminder_opt_in { 0 }

sub garden_current_service_from_service_units {
    my ($self, $services) = @_;

    my $garden;
    for my $service ( @$services ) {
        my $servicetasks = $self->_get_service_tasks($service);
        foreach my $task (@$servicetasks) {
            if ( $task->{TaskTypeId} == $self->garden_service_id ) {
                $garden = $self->_get_current_service_task($service);
                last;
            }
        }
    }
    return $garden;
}

sub garden_container_data_extract {
    my ($self, $data, $containers, $quantities, $schedules) = @_;
    # Assume garden will only have one container data
    my $garden_container = $containers->[0];
    if ($garden_container == CONTAINER_GARDEN_SACK) {
        my $garden_cost = $self->garden_waste_renewal_sacks_cost_pa($schedules->{end_date}) / 100;
        return (undef, 1, $garden_cost, $garden_container);
    } else {
        my $garden_bins = $quantities->{$containers->[0]};
        my $garden_cost = $self->garden_waste_renewal_cost_pa($schedules->{end_date}, $garden_bins) / 100;
        return ($garden_bins, 0, $garden_cost, $garden_container);
    }
}

# We don't have overdue renewals here
sub waste_sub_overdue { 0 }

sub waste_garden_sub_params {
    my ($self, $data, $type) = @_;
    my $c = $self->{c};

    my $service = $self->garden_current_subscription;
    my $choice = $data->{container_choice} || '';
    my $existing = $service ? $service->{garden_container} : undef;
    my $container;
    if ($choice eq 'sack') {
        $container = CONTAINER_GARDEN_SACK;
    } elsif ($choice eq 'bin140') {
        $container = CONTAINER_GARDEN_BIN_140;
    } elsif ($choice eq 'bin240') {
        $container = CONTAINER_GARDEN_BIN;
    } elsif ($choice) {
        $container = CONTAINER_GARDEN_BIN;
    } elsif ($existing) {
        $container = $existing;
    } else {
        $container = CONTAINER_GARDEN_BIN;
    }

    my $container_actions = {
        deliver => 1,
        remove => 2
    };

    $c->set_param('Request_Type', $type);
    $c->set_param('Subscription_Details_Containers', $container);
    $c->set_param('Subscription_Details_Quantity', $data->{bins_wanted});

    if ($c->cobrand->moniker eq 'merton'        # Might work okay for K/S too, but only Merton have asked
        && $existing                            # This is a renewal, not a new subscription
        && $existing != $container              # We're changing container type
        && $existing != CONTAINER_GARDEN_SACK   # If currently sack, there's nothing to remove, same as new
    ) {
        # We need to ask for both a delivery and a removal of the old bins
        $c->set_param('Bin_Delivery_Detail_Containers', join('::', 1, 2)); # deliver and remove
        $c->set_param('Bin_Delivery_Detail_Container', join('::', $container, $existing));
        $c->set_param('Bin_Delivery_Detail_Quantity', join('::', $data->{bins_wanted}, $data->{current_bins}));
    } elsif ( $data->{new_bins} ) {
        my $action = ($data->{new_bins} > 0) ? 'deliver' : 'remove';
        $c->set_param('Bin_Delivery_Detail_Containers', $container_actions->{$action});
        $c->set_param('Bin_Delivery_Detail_Container', $container);
        $c->set_param('Bin_Delivery_Detail_Quantity', abs($data->{new_bins}));
    }

    if ($c->cobrand->moniker eq 'merton' && $data->{new_bins} && !$type) { # Cancellation
        $c->set_param('Bin_Detail_Type', $container_actions->{remove});
        $c->set_param('Bin_Detail_Container', $existing);
        $c->set_param('Bin_Detail_Quantity', abs($data->{new_bins}));
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
            if ($service->{garden_container} == 28) {
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

        my $ref = $row->get_extra_field_value('PaymentCode') || $row->get_extra_metadata('chequeReference');
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
sub _bulky_refund_cutoff_date { }

sub bulky_allowed_property {
    my ( $self, $property ) = @_;

    return if $property->{has_no_services};
    my $cfg = $self->feature('echo');

    my $type = $property->{type_id} || 0;
    my $valid_type = grep { $_ == $type } @{ $cfg->{bulky_address_types} || [] };
    my $domestic_farm = $type != 7 || $property->{domestic_refuse_bin};
    return $self->bulky_enabled && $valid_type && $domestic_farm;
}

sub collection_date {
    my ($self, $p) = @_;
    return $self->_bulky_date_to_dt($p->get_extra_field_value('Collection_Date'));
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
    my ($date, $ref, $expiry) = split(";", $data->{chosen_date});

    my $guid_key = $self->council_url . ":echo:bulky_event_guid:" . $c->stash->{property}->{id};
    $data->{extra_GUID} = $self->{c}->waste_cache_get($guid_key);
    $data->{extra_reservation} = $ref;

    $data->{title} = "Bulky goods collection";
    $data->{detail} = "Address: " . $c->stash->{property}->{address};
    $data->{category} = "Bulky collection";
    $data->{extra_Collection_Date} = $date;
    $data->{extra_Exact_Location} = $data->{location};

    my $first_date = $self->{c}->session->{first_date_returned};
    $first_date = DateTime::Format::W3CDTF->parse_datetime($first_date);
    my $dt = DateTime::Format::W3CDTF->parse_datetime($date);
    $data->{'extra_First_Date_Returned_to_Customer'} = $first_date->strftime("%d/%m/%Y");
    $data->{'extra_Customer_Selected_Date_Beyond_SLA?'} = $dt > $first_date ? 1 : 0;

    my @items_list = @{ $self->bulky_items_master_list };
    my %items = map { $_->{name} => $_->{bartec_id} } @items_list;

    my @notes;
    my @ids;
    my @photos;

    my $max = $self->bulky_items_maximum;
    for (1..$max) {
        if (my $item = $data->{"item_$_"}) {
            push @notes, $data->{"item_notes_$_"} || '';
            push @ids, $items{$item};
            push @photos, $data->{"item_photos_$_"} || '';
        };
    }
    $data->{extra_Bulky_Collection_Notes} = join("::", @notes);
    $data->{extra_Bulky_Collection_Bulky_Items} = join("::", @ids);
    $data->{extra_Image} = join("::", @photos);
    $self->bulky_total_cost($data);
}

sub waste_reconstruct_bulky_data {
    my ($self, $p) = @_;

    my $saved_data = {
        "chosen_date" => $p->get_extra_field_value('Collection_Date'),
        "location" => $p->get_extra_field_value('Exact_Location'),
        "location_photo" => $p->get_extra_metadata("location_photo"),
    };

    my @fields = split /::/, $p->get_extra_field_value('Bulky_Collection_Bulky_Items');
    my @notes = split /::/, $p->get_extra_field_value('Bulky_Collection_Notes');
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
