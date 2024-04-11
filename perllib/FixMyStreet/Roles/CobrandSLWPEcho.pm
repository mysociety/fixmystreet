=head1 NAME

FixMyStreet::Roles::CobrandSLWPEcho - shared code for anything with the SLWP Echo

=head1 DESCRIPTION

=cut

package FixMyStreet::Roles::CobrandSLWPEcho;

use Moo::Role;
with 'FixMyStreet::Roles::CobrandEcho';

use Integrations::Echo;
use JSON::MaybeXS;
use LWP::Simple;

around look_up_property => sub {
    my ($orig, $self, $id) = @_;
    my $data = $orig->($self, $id);

    my $cfg = $self->feature('echo');
    if ($cfg->{nlpg} && $data->{uprn} && !$self->{c}->stash->{partial_loading}) {
        my $uprn_data = get(sprintf($cfg->{nlpg}, $data->{uprn}));
        $uprn_data = JSON::MaybeXS->new->decode($uprn_data) if $uprn_data;
        if (!$uprn_data || $uprn_data->{results}[0]{LPI}{LOCAL_CUSTODIAN_CODE_DESCRIPTION} ne $self->lpi_value) {
            $self->{c}->stash->{template} = 'waste/missing.html';
            $self->{c}->detach;
        }
    }
    return $data;
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

use constant CONTAINER_REFUSE_140 => 1;
use constant CONTAINER_REFUSE_240 => 2;
use constant CONTAINER_REFUSE_360 => 3;
use constant CONTAINER_RECYCLING_BIN => 12;
use constant CONTAINER_RECYCLING_BOX => 16;
use constant CONTAINER_PAPER_BIN => 19;
use constant CONTAINER_PAPER_BIN_140 => 36;

use constant GARDEN_WASTE_SERVICE_ID => 2247;

sub waste_service_to_containers { () }

sub garden_subscription_event_id { 1638 }

sub waste_relevant_serviceunits {
    my ($self, $result) = @_;
    my @rows;
    foreach (@$result) {
        my $servicetasks = $self->_get_service_tasks($_);
        foreach my $task (@$servicetasks) {
            my $service_id = $task->{TaskTypeId};
            my $service_name = $self->service_name_override({ ServiceId => $service_id });
            next unless $service_name;

            my $schedules = _parse_schedules($task, 'task');

            # Ignore retired diesel rounds
            next if $self->moniker eq 'kingston' && !$schedules->{next} && $service_id != GARDEN_WASTE_SERVICE_ID;

            push @rows, {
                Id => $task->{Id},
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

    if (!(@$result && grep { $_->{ServiceId} == 409 } @$result)) {
        # No garden collection possible
        $self->{c}->stash->{waste_features}->{garden_disabled} = 1;
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

my %waste_containers_no_request = (
    6 => 1, # Red stripe bag
    17 => 1, # Recycling purple sack
    29 => 1, # Recycling Single Use Bag
    21 => 1, # Paper & Card Reusable bag
);

sub waste_service_containers {
    my ($self, $service) = @_;

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
        next if $waste_containers_no_request{$container};
        next if $container == 18 && $schedules->{description} !~ /fortnight/; # Blue stripe bag on a weekly collection
        if ($container && $quantity) {
            # Store this fact here for use in new request flow
            $self->{c}->stash->{container_recycling_bin} = 1 if $container == CONTAINER_RECYCLING_BIN;
            push @$containers, $container;
            next if $container == 28; # Garden waste bag
            # The most you can request is one
            $request_max->{$container} = 1;
            $self->{c}->stash->{quantities}->{$container} = $quantity;

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

    if ($service_name =~ /Food/) {
        # Can always request a food caddy
        push @$containers, 23; # Food waste bin (kitchen)
        $request_max->{23} = 1;
    }
    if ($self->moniker eq 'kingston' && grep { $_ == CONTAINER_RECYCLING_BOX } @$containers) {
        # Can request a bin if you have a box
        push @$containers, CONTAINER_RECYCLING_BIN;
        $request_max->{+CONTAINER_RECYCLING_BIN} = 1;
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

sub waste_munge_request_data {
    my ($self, $id, $data, $form) = @_;

    my $c = $self->{c};
    my $address = $c->stash->{property}->{address};
    my $container = $c->stash->{containers}{$id};
    my $quantity = $data->{recycling_quantity} || 1;
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
        if ($data->{recycling_swap} eq 'Yes') {
            # $id has to be 16 here but we want to swap it for a 12
            my $q = $c->stash->{quantities}{+CONTAINER_RECYCLING_BOX} || 1;
            $action_id = ('2::' x $q) . '1'; # Collect and Deliver
            $reason_id = ('3::' x $q) . '3'; # Change capacity
            $id = ((CONTAINER_RECYCLING_BOX . '::') x $q) . CONTAINER_RECYCLING_BIN;
            $container = $c->stash->{containers}{+CONTAINER_RECYCLING_BIN};
        } else {
            $action_id = 1; # Deliver
            $reason_id = 3; # Change capacity
        }
    } elsif ($reason eq 'change_capacity') {
        $action_id = '2::1';
        $reason_id = '3::3';
        if ($id == CONTAINER_REFUSE_140) {
            $id = CONTAINER_REFUSE_240 . '::' . CONTAINER_REFUSE_140;
        } elsif ($id == CONTAINER_REFUSE_240) {
            if ($c->stash->{quantities}{+CONTAINER_REFUSE_360}) {
                $id = CONTAINER_REFUSE_360 . '::' . CONTAINER_REFUSE_240;
            } else {
                $id = CONTAINER_REFUSE_140 . '::' . CONTAINER_REFUSE_240;
            }
        } elsif ($id == CONTAINER_PAPER_BIN) {
            $id = CONTAINER_PAPER_BIN_140 . '::' . CONTAINER_PAPER_BIN;
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
    if ($data->{notes_missing}) {
        $data->{detail} .= " - $data->{notes_missing}";
        $c->set_param('Notes', $data->{notes_missing});
    }
    if ($data->{notes_damaged}) {
        my $notes = $c->stash->{label_for_field}->($form, 'notes_damaged', $data->{notes_damaged});
        $data->{detail} .= " - $notes";
        $c->set_param('Notes', $notes);
    }
    $c->set_param('Container_Type', $id);
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
    $data->{title} = "Report missed $service";
    $data->{detail} = "$data->{title}\n\n$address";
    if ($booking_report) {
        $c->set_param('Exact_Location', $booking_report->get_extra_field_value('Exact_Location'));
        $c->set_param('Original_Event_ID', $booking_report->external_id);
    }
    $c->set_param('Notes', $data->{extra_detail}) if $data->{extra_detail};
    $c->set_param('service_id', $id);
}

1;
