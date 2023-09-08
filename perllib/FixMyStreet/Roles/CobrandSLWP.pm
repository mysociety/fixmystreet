=head1 NAME

FixMyStreet::Roles::CobrandSLWP - shared code for Kingston and Sutton WasteWorks

=head1 DESCRIPTION

=cut

package FixMyStreet::Roles::CobrandSLWP;

use Moo::Role;
with 'FixMyStreet::Roles::CobrandEcho';
with 'FixMyStreet::Roles::CobrandBulkyWaste';

use Integrations::Echo;
use JSON::MaybeXS;
use LWP::Simple;
use FixMyStreet::WorkingDays;
use FixMyStreet::App::Form::Waste::Garden::Sacks;
use FixMyStreet::App::Form::Waste::Garden::Sacks::Renew;
use FixMyStreet::App::Form::Waste::Report::SLWP;
use FixMyStreet::App::Form::Waste::Request::Kingston;
use FixMyStreet::App::Form::Waste::Request::Sutton;

=head2 Defaults

=over 4

=item * We do not send questionnaires.

=cut

sub send_questionnaires { 0 }

=item * The contact form is for abuse reports only

=cut

sub abuse_reports_only { 1 }

=item * Only waste reports are shown on the cobrand

=cut

around problems_restriction => sub {
    my ($orig, $self, $rs) = @_;
    return $rs if FixMyStreet->staging_flag('skip_checks');
    $rs = $orig->($self, $rs);
    my $table = ref $rs eq 'FixMyStreet::DB::ResultSet::Nearby' ? 'problem' : 'me';
    $rs = $rs->search({
        "$table.cobrand_data" => 'waste',
    });
    return $rs;
};

sub problems_on_dashboard {
    my ($self, $rs) = @_;

    my $bodies = [ $self->body->id ];
    my $extra = $self->dashboard_extra_bodies;
    push @$bodies, $extra->id if $extra;
    $rs = FixMyStreet::DB->resultset('Problem')->to_body($bodies)->search({
        "me.cobrand_data" => 'waste',
    });
    return $rs;
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
    if ($error =~ /Cannot renew this property, a new request is required/ && $row->title eq "Garden Subscription - Renew") {
        # Was created as a renewal, but due to DD delay has now expired. Switch to new subscription
        $row->title("Garden Subscription - New");
        $row->update_extra_field({ name => "Request_Type", value => $self->waste_subscription_types->{New} });
    }
    if ($error =~ /Missed Collection event already open for the property/) {
        $row->state('duplicate');
    }

    if ($error =~ /Duplicate Event! Original eventID: (\d+)/) {
        my $id = $1;
        my $cfg = $self->feature('echo');
        my $echo = Integrations::Echo->new(%$cfg);
        my $event = $echo->GetEvent($id, 'Id');
        $row->external_id($event->{Guid});
        $sender->success(1);
    }
}

=item * No updates on waste reports

=cut

around updates_disallowed => sub {
    my ($orig, $self, $problem) = @_;

    # No updates on waste reports
    return 'waste' if $problem->cobrand_data eq 'waste';

    return $orig->($self, $problem);
};

=item * Allow both Kingston and Sutton users access to the cobrand admin

=cut

sub admin_allow_user {
    my ( $self, $user ) = @_;
    return 1 if $user->is_superuser;
    return undef unless defined $user->from_body;
    my $user_cobrand = $user->from_body->get_extra_metadata('cobrand', '');
    return $user_cobrand =~ /kingston|sutton/;
}

# Let Kingston/Sutton staff users share permissions
sub permission_body_override {
    my ($self, $body_ids) = @_;

    my $kingston = FixMyStreet::Cobrand::Kingston->new->body;
    my $sutton = FixMyStreet::Cobrand::Sutton->new->body;
    return unless $kingston && $sutton;

    my @out = map {
        if ($kingston->id == $_) {
            ($_, $sutton->id);
        } elsif ($sutton->id == $_) {
            ($_, $kingston->id);
        } else {
            $_;
        }
    } @$body_ids;

    return \@out;
}

sub state_groups_admin {
    [
        [ New => [ 'confirmed' ] ],
        [ Pending => [ 'investigating', 'action scheduled' ] ],
        [ Closed => [ 'fixed - council', 'unable to fix', 'closed', 'duplicate' ] ],
        [ Hidden => [ 'unconfirmed', 'hidden', 'partial' ] ],
    ]
}

# Cut down list as only Waste
sub available_permissions {
    my $self = shift;

    return {
        _("Problems") => {
            report_edit => _("Edit reports"),
            report_mark_private => _("View/Mark private reports"),
            contribute_as_another_user => _("Create reports/updates on a user's behalf"),
            contribute_as_anonymous_user => _("Create reports/updates as anonymous user"),
            contribute_as_body => _("Create reports/updates as the council"),
        },
        _("Users") => {
            user_edit => _("Edit users' details/search for their reports"),
            user_manage_permissions => _("Edit other users' permissions"),
            user_assign_body => _("Grant access to the admin"),
        },
        _("Bodies") => {
            template_edit => _("Add/edit response templates"),
            emergency_message_edit => _("Add/edit site message"),
        },
    };
}

sub clear_cached_lookups_property {
    my ( $self, $id, $skip_echo ) = @_;

    # Need to call this before clearing GUID
    $self->clear_cached_lookups_bulky_slots( $id, $skip_echo );

    foreach my $key (
        $self->council_url . ":echo:look_up_property:$id",
        $self->council_url . ":echo:bin_services_for_address:$id",
        $self->council_url . ":echo:bulky_event_guid:$id",
    ) {
        delete $self->{c}->session->{$key};
    }
}

sub clear_cached_lookups_bulky_slots {
    my ( $self, $id, $skip_echo ) = @_;

    for (qw/earlier later/) {
        delete $self->{c}->session->{ $self->council_url
                . ":echo:available_bulky_slots:$_:$id" };
    }

    return if $skip_echo;

    # We also need to cancel the reserved slots in Echo
    my $guid_key = $self->council_url . ":echo:bulky_event_guid:$id";
    my $guid = $self->{c}->session->{$guid_key};

    return unless $guid;

    my $cfg = $self->feature('echo');
    my $echo = Integrations::Echo->new(%$cfg);
    $echo->CancelReservedSlotsForEvent($guid);
}

around look_up_property => sub {
    my ($orig, $self, $id) = @_;
    my $data = $orig->($self, $id);

    $data->{pending_bulky_collection}
        = $self->find_pending_bulky_collection($data);

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

sub waste_never_confirm_reports { 1 }

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
    };
}

use constant CONTAINER_RECYCLING_BIN => 12;
use constant CONTAINER_RECYCLING_BOX => 16;

use constant GARDEN_WASTE_SERVICE_ID => 2247;
sub garden_service_name { 'garden waste collection service' }
sub garden_service_id { GARDEN_WASTE_SERVICE_ID }
sub garden_current_subscription { shift->{c}->stash->{services}{+GARDEN_WASTE_SERVICE_ID} }
sub get_current_garden_bins { shift->garden_current_subscription->{garden_bins} }

sub garden_subscription_type_field { 'Request_Type' }
sub garden_subscription_container_field { 'Subscription_Details_Containers' }
sub garden_echo_container_name { 'SLWP - Containers' }
sub garden_due_days { 30 }

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

    return $service_name_override{$service} // '';
}

sub bin_payment_types {
    return {
        'csc' => 1,
        'credit_card' => 2,
        'direct_debit' => 3,
        'cheque' => 4,
    };
}

sub waste_password_hidden { 1 }

sub waste_subscription_types {
    return {
        New => 1,
        Renew => 2,
        Amend => 3,
    };
}

sub waste_container_actions {
    return {
        deliver => 1,
        remove => 2
    };
}

# For renewal/modify
sub waste_allow_current_bins_edit { 1 }

sub bin_services_for_address {
    my $self = shift;
    my $property = shift;

    my %shared = (
            23 => 'Food waste bin (kitchen)',
            24 => 'Food waste bin (outdoor)',
            6 => 'Refuse Red Stripe Bag',
            18 => 'Recycling Blue Stripe Bag',
            21 => 'Paper & Card Reusable Bag',
            30 => 'Paper Single Use Bag',
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
            12 => 'Recycling bin (240L)',
            13 => 'Recycling bin (360L)',
            20 => 'Paper recycling bin (360L)',
            31 => 'Paper 55L Box',
    );
    if ($self->moniker eq 'sutton') {
        $self->{c}->stash->{containers} = {
            %shared,
            1 => 'Brown rubbish bin (140L)',
            2 => 'Brown rubbish bin (240L)',
            3 => 'Brown rubbish bin (360L)',
            35 => 'Rubbish bin (180L)',
            16 => 'Green recycling box',
            19 => 'Green paper and cardboard bin',
            26 => 'Garden waste bin',
            27 => 'Garden waste bin',
            28 => 'Garden waste sacks',
        };
    } elsif ($self->moniker eq 'kingston') {
        $self->{c}->stash->{containers} = {
            %shared,
            1 => 'Black rubbish bin (140L)',
            2 => 'Black rubbish bin (240L)',
            3 => 'Black rubbish bin (360L)',
            35 => 'Black rubbish bin (180L)',
            12 => 'Green recycling bin (240L)',
            13 => 'Green recycling bin (360L)',
            16 => 'Green recycling box (55L)',
            19 => 'Blue lid paper and cardboard bin (240L)',
            20 => 'Blue lid paper and cardboard bin (360L)',
            36 => 'Blue lid paper and cardboard bin (180L)',
            26 => 'Garden waste bin (240L)',
            27 => 'Garden waste bin (140L)',
            28 => 'Garden waste sacks',
        };
    }

    $self->{c}->stash->{container_actions} = $self->waste_container_actions;

    my %quantity_max = (
        2247 => 5, # Garden waste maximum
    );
    $self->{c}->stash->{quantity_max} = \%quantity_max;
    my $quantities = $self->{c}->stash->{quantities} = {};

    $self->{c}->stash->{garden_subs} = $self->waste_subscription_types;

    my $result = $self->{api_serviceunits};
    unless (@$result && grep { $_->{ServiceId} == 409 } @$result) {
        # No garden collection possible
        $self->{c}->stash->{waste_features}->{garden_disabled} = 1;
    }

    my $events = $self->_parse_events($self->{api_events});
    $self->{c}->stash->{open_service_requests} = $events->{enquiry};

    # If there is an open Garden subscription (1638) event, assume
    # that means a bin is being delivered and so a pending subscription
    if ($events->{enquiry}{1638}) {
        $self->{c}->stash->{pending_subscription} = { title => 'Garden Subscription - New' };
        $self->{c}->stash->{open_garden_event} = 1;
    }

    my @to_fetch;
    my %schedules;
    my @task_refs;
    foreach (@$result) {
        my $servicetasks = $self->_get_service_tasks($_);
        foreach my $task (@$servicetasks) {
            my $task_id = $task->{Id};
            my $service_id = $task->{TaskTypeId};
            my $service_name = $self->service_name_override($service_id);
            next unless $service_name;

            if ($service_id == 2242) { # Collect Domestic Refuse Bag
                $self->{c}->stash->{slwp_garden_sacks} = 1;
            }

            my $schedules = _parse_schedules($task, 'task');

            next unless $schedules->{next} or $schedules->{last};
            $schedules{$task_id} = $schedules;
            push @to_fetch, GetEventsForObject => [ ServiceUnit => $_->{Id} ];
            push @task_refs, $schedules->{last}{ref} if $schedules->{last};
        }
    }
    push @to_fetch, GetTasks => \@task_refs if @task_refs;

    my $cfg = $self->feature('echo');
    my $echo = Integrations::Echo->new(%$cfg);
    my $calls = $echo->call_api($self->{c}, $self->council_url, 'bin_services_for_address:' . $property->{id}, 1, @to_fetch);

    $property->{show_bulky_waste} = $self->bulky_allowed_property($property);

    my @out;
    my %task_ref_to_row;
    foreach (@$result) {
        my $data = Integrations::Echo::force_arrayref($_->{Data}, 'ExtensibleDatum');
        foreach (@$data) {
            $self->{c}->stash->{assisted_collection} = 1 if $_->{DatatypeName} eq "Assisted Collection" && $_->{Value};
        }

        my $servicetasks = $self->_get_service_tasks($_);
        foreach my $task (@$servicetasks) {
            my $task_id = $task->{Id};
            my $service_id = $task->{TaskTypeId};
            my $service_name = $self->service_name_override($service_id);
            next unless $service_name;
            next unless $schedules{$task_id};

            my $schedules = $schedules{$task_id};

            $self->{c}->stash->{communal_property} = 1 if $service_id == 2243 || $service_id == 2248 || $service_id == 2249 || $service_id == 2250; # Communal

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
                next if $container == 6; # Red stripe bag
                next if $container == 18 && $schedules->{description} !~ /fortnight/; # Blue stripe bag on a weekly collection
                if ($container && $quantity) {
                    # Store this fact here for use in new request flow
                    $self->{c}->stash->{container_recycling_bin} = 1 if $container == CONTAINER_RECYCLING_BIN;
                    push @$containers, $container;
                    next if $container == 28; # Garden waste bag
                    # The most you can request is one
                    $request_max->{$container} = 1;
                    $quantities->{$container} = $quantity;
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

            my $open_requests = { map { $_ => $events->{request}->{$_} } grep { $events->{request}->{$_} } @$containers };

            my $garden = 0;
            my $garden_bins;
            my $garden_container;
            my $garden_cost = 0;
            my $garden_due;
            my $garden_overdue = 0; # No 'overdue' notice
            if ($service_name eq 'Garden Waste') {
                $garden = 1;
                $garden_due = $self->waste_sub_due($schedules->{end_date});
                foreach (@$data) {
                    next unless $_->{DatatypeName} eq $self->garden_echo_container_name; # DatatypeId 3346
                    # Assume garden will only have one container data
                    $garden_container = $containers->[0];
                    $garden_bins = $quantities->{$containers->[0]};
                    if ($garden_container == 28) {
                        $garden_cost = $self->garden_waste_sacks_cost_pa() / 100;
                    } else {
                        $garden_cost = $self->garden_waste_cost_pa($garden_bins) / 100;
                    }

                }

                if ($self->{c}->stash->{waste_features}->{garden_disabled}) {
                    $garden = 0;
                }
            }

            my $row = {
                id => $_->{Id},
                service_id => $service_id,
                service_name => $service_name,
                garden_waste => $garden,
                garden_container => $garden_container,
                garden_bins => $garden_bins,
                garden_cost => $garden_cost,
                garden_due => $garden_due,
                garden_overdue => $garden_overdue,
                request_allowed => $request_max && $schedules->{next},
                requests_open => $open_requests,
                request_containers => $containers,
                request_max => $request_max,
                service_task_id => $task->{Id},
                schedule => $schedules->{description},
                last => $schedules->{last},
                next => $schedules->{next},
                end_date => $schedules->{end_date},
            };
            if ($row->{last}) {
                my $ref = join(',', @{$row->{last}{ref}});
                $task_ref_to_row{$ref} = $row;

                $row->{report_allowed} = $self->within_working_days($row->{last}{date}, 2);

                my $events_unit = $self->_parse_events($calls->{"GetEventsForObject ServiceUnit $_->{Id}"});
                my $missed_events = [
                    @{$events->{missed}->{$service_id} || []},
                    @{$events_unit->{missed}->{$service_id} || []},
                ];
                my $recent_events = $self->_events_since_date($row->{last}{date}, $missed_events);
                $row->{report_open} = $recent_events->{open} || $recent_events->{closed};
            }
            push @out, $row;
        }
    }

    $self->waste_task_resolutions($calls->{GetTasks}, \%task_ref_to_row);

    return \@out;
}

sub _closed_event {
    my $event = shift;
    return 1 if $event->{ResolvedDate};
#    return 1 if $event->{ResolutionCodeId} && $event->{ResolutionCodeId} != 584; # Out of Stock TODO Check this
    return 0;
}

sub _parse_events {
    my $self = shift;
    my $events_data = shift;
    my $events;
    foreach (@$events_data) {
        my $event_type = $_->{EventTypeId};
        my $type = 'enquiry';
        $type = 'request' if $event_type == 1635;
        $type = 'missed' if $event_type == 1566 || $event_type == 1568;

        # Only care about open requests/enquiries
        my $closed = _closed_event($_);
        next if $type ne 'missed' && $closed;

        if ($type eq 'request') {
            my $report = $self->problems->search({ external_id => $_->{Guid} })->first;
            my $data = Integrations::Echo::force_arrayref($_->{Data}, 'ExtensibleDatum');
            foreach (@$data) {
                my $moredata = Integrations::Echo::force_arrayref($_->{ChildData}, 'ExtensibleDatum');
                foreach (@$moredata) {
                    if ($_->{DatatypeName} eq 'Container Type') {
                        my $container = $_->{Value};
                        $events->{request}->{$container} = $report ? { report => $report } : 1;
                    }
                }
            }
        } elsif ($type eq 'missed') {
            my $report = $self->problems->search({ external_id => $_->{Guid} })->first;
            my $event = {
                closed => $closed,
                date => construct_bin_date($_->{EventDate}),
            };
            $event->{report} = $report if $report;

            my $service_id = $_->{ServiceId};
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
            } elsif ($service_id == 408 || $service_id == 410) {
                my $data = Integrations::Echo::force_arrayref($_->{Data}, 'ExtensibleDatum');
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
        } else { # General enquiry of some sort
            $events->{enquiry}->{$event_type} = 1;
        }
    }
    return $events;
}

sub bin_day_format { '%A, %-d~~~ %B' }

=head2 within_working_days

Given a DateTime object and a number, return true if today is less than or
equal to that number of working days (excluding Sundays and bank holidays)
after the date.

=cut

sub within_working_days {
    my ($self, $dt, $days, $future) = @_;
    my $wd = FixMyStreet::WorkingDays->new(
        public_holidays => FixMyStreet::Cobrand::UK::public_holidays(),
        $self->council_url eq 'sutton' ? (saturdays => 1) : (),
    );
    $dt = $wd->add_days($dt, $days)->ymd;
    my $today = DateTime->now->set_time_zone(FixMyStreet->local_time_zone)->ymd;
    if ( $future ) {
        return $today ge $dt;
    } else {
        return $today le $dt;
    }
}

# Not in the function below because it needs to set things needed before then
# (perhaps could be refactored better at some point). Used for new/renew
sub waste_garden_sub_payment_params {
    my ($self, $data) = @_;
    my $c = $self->{c};

    # Special sack form handling
    my $container = $data->{container_choice} || '';
    if ($container eq 'sack') {
        $data->{slwp_garden_sacks} = 1;
        $data->{bin_count} = 1;
        $data->{new_bins} = 1;
        my $cost_pa = $c->cobrand->garden_waste_sacks_cost_pa();
        ($cost_pa) = $c->cobrand->apply_garden_waste_discount($cost_pa) if $data->{apply_discount};
        $c->set_param('payment', $cost_pa);
    }
}

sub waste_garden_sub_params {
    my ($self, $data, $type) = @_;
    my $c = $self->{c};

    my $service = $self->garden_current_subscription;
    my $existing = $service ? $service->{garden_container} : undef;
    my $container = $data->{slwp_garden_sacks} ? 28 : $existing || 26;

    $c->set_param('Request_Type', $type);
    $c->set_param('Subscription_Details_Containers', $container);
    $c->set_param('Subscription_Details_Quantity', $data->{bin_count});
    if ( $data->{new_bins} ) {
        my $action = ($data->{new_bins} > 0) ? 'deliver' : 'remove';
        $c->set_param('Bin_Delivery_Detail_Containers', $c->stash->{container_actions}->{$action});
        $c->set_param('Bin_Delivery_Detail_Container', $container);
        $c->set_param('Bin_Delivery_Detail_Quantity', abs($data->{new_bins}));
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
        $c->stash->{first_page} = 'sacks_choice';
        $c->stash->{form_class} = 'FixMyStreet::App::Form::Waste::Garden::Sacks::Renew';
    }
}

sub waste_report_extra_dd_data {
    my ($self) = @_;
    my $c = $self->{c};

    if (my $orig = $c->stash->{orig_sub}) {
        my $p = $c->stash->{report};
        $p->set_extra_metadata(dd_contact_id => $orig->get_extra_metadata('dd_contact_id'))
            if $orig->get_extra_metadata('dd_contact_id');
        $p->set_extra_metadata(dd_mandate_id => $orig->get_extra_metadata('dd_mandate_id'))
            if $orig->get_extra_metadata('dd_mandate_id');
        $p->update;
    }
}

=head2 waste_munge_report_form_fields

We use a custom report form to add some text to the "About you" page.

=cut

sub waste_munge_report_form_fields {
    my ($self, $field_list) = @_;
    $self->{c}->stash->{form_class} = 'FixMyStreet::App::Form::Waste::Report::SLWP';
}

=head2 waste_munge_request_form_fields

Replace the usual checkboxes grouped by service with one radio list of
containers.

=cut

sub waste_munge_request_form_fields {
    my ($self, $field_list) = @_;

    my @radio_options;
    my %seen;
    for (my $i=0; $i<@$field_list; $i+=2) {
        my ($key, $value) = ($field_list->[$i], $field_list->[$i+1]);
        next unless $key =~ /^container-(\d+)/;
        my $id = $1;
        next if $self->moniker eq 'kingston' && $seen{$id};
        push @radio_options, {
            value => $id,
            label => $self->{c}->stash->{containers}->{$id},
            disabled => $value->{disabled},
        };
        $seen{$id} = 1;
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
picked a bag, to the swap-for-a-bin page if they've picked a bin, don't already
have a bin and are on Kingston; otherwise we move to asking for a reason.

=cut

sub waste_request_form_first_next {
    my $self = shift;
    my $cls = ucfirst $self->council_url;
    $self->{c}->stash->{form_class} = "FixMyStreet::App::Form::Waste::Request::$cls";
    $self->{c}->stash->{form_title} = 'Which container do you need?';
    return sub {
        my $data = shift;
        my $choice = $data->{"container-choice"};
        return 'about_you' if $choice == 18 || $choice == 30;
        if ($cls eq 'Kingston' && $choice == CONTAINER_RECYCLING_BIN && !$self->{c}->stash->{container_recycling_bin}) {
            $data->{request_reason} = 'more';
            return 'recycling_swap';
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
    } else {
        # No reason, must be a bag
        $action_id = 1; # Deliver
        $reason_id = 3; # Change capacity
        $nice_reason = "Additional bag required";
    }

    $data->{title} = "Request new $container";
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

    my $address = $c->stash->{property}->{address};
    my $service = $c->stash->{services}{$id}{service_name};
    $data->{title} = "Report missed $service";
    $data->{detail} = "$data->{title}\n\n$address";
    $c->set_param('service_id', $id);
}

# Same as full cost
sub waste_get_pro_rata_cost {
    my ($self, $bins, $end) = @_;
    return $self->garden_waste_cost_pa($bins);
}

sub waste_display_payment_method {
    my ($self, $method) = @_;

    my $display = {
        direct_debit => _('Direct Debit'),
        credit_card => _('Credit Card'),
    };

    return $display->{$method};
}

sub garden_waste_new_bin_admin_fee {
    my ($self, $new_bins) = @_;
    $new_bins ||= 0;

    my $per_new_bin_first_cost = $self->feature('payment_gateway')->{ggw_new_bin_first_cost};
    my $per_new_bin_cost = $self->feature('payment_gateway')->{ggw_new_bin_cost};

    my $cost = 0;
    if ($new_bins > 0) {
        $cost += $per_new_bin_first_cost;
        if ($new_bins > 1) {
            $cost += $per_new_bin_cost * ($new_bins - 1);
        }
    }
    return $cost;
}

=head2 waste_cc_payment_line_item_ref

This is only used by Kingston (which uses the SCP role) to provide the
reference for the credit card payment. It differs for bulky waste.

=cut

sub waste_cc_payment_line_item_ref {
    my ($self, $p) = @_;
    if ($p->category eq 'Bulky collection') {
        my $id = $p->id;
        my $len = 50 - length($id) - 1;
        my $name = substr($p->name, 0, $len);
        return "$id-$name";
    } else {
        return $self->_waste_cc_line_item_ref($p, "GW Sub");
    }
}

sub waste_cc_payment_admin_fee_line_item_ref {
    my ($self, $p) = @_;
    return $self->_waste_cc_line_item_ref($p, "GW admin charge");
}

sub _waste_cc_line_item_ref {
    my ($self, $p, $str) = @_;
    my $id = $self->waste_payment_ref_council_code . '-GGW-' . $p->id;
    my $len = 50 - length($id) - length($str) - 2;
    my $name = substr($p->name, 0, $len);
    return "$id-$name-$str";
}

sub waste_cc_payment_sale_ref {
    my ($self, $p) = @_;
    return "GGW" . $p->get_extra_field_value('uprn');
}

sub garden_waste_dd_munge_form_details {
    my ($self, $c) = @_;

    $c->stash->{form_name} = $c->stash->{payment_details}->{form_name};
    if ( $c->stash->{staff_payments_allowed} ) {
        $c->stash->{form_name} = $c->stash->{payment_details}->{staff_form_name};
    }

    my $cfg = $self->feature('echo');
    if ($cfg->{nlpg} && $c->stash->{property}{uprn}) {
        my $uprn_data = get(sprintf($cfg->{nlpg}, $c->stash->{property}{uprn}));
        $uprn_data = JSON::MaybeXS->new->decode($uprn_data);
        my $address = $self->get_address_details_from_nlpg($uprn_data);
        if ( $address ) {
            $c->stash->{address1} = $address->{address1};
            $c->stash->{address2} = $address->{address2};
            $c->stash->{town} = $address->{town};
            $c->stash->{postcode} = $address->{postcode};
        }
    }
}

sub garden_waste_dd_redirect_url {
    my ($self, $p) = @_;

    my $c = $self->{c};

    return $c->cobrand->base_url_with_lang . "/waste/dd_complete";
}

sub garden_waste_dd_check_success {
    my ($self, $c) = @_;

    if ( defined( $c->get_param('stage') ) && $c->get_param('stage') == 0 ) {
        # something has gone wrong and the form has not recorded correctly
        $c->forward('direct_debit_error');
        $c->detach();
    # check if the bank details have been verified
    } elsif ( $c->get_param('verificationapplied') && lc($c->get_param('verificationapplied')) eq 'true' ) {
        # and if they have and verification has failed then redirect
        # to the cancelled page
        if ( lc $c->get_param('status') eq 'false') {
            $c->forward('direct_debit_error');
            $c->detach();
        }
    }
}

sub garden_waste_dd_get_redirect_params {
    my ($self, $c) = @_;

    my $data = $c->get_param('customData');

    my %params = map {
        my ($key, $value) = split ':';
        $key => $value;
    } split '\^', $data;

    return ($params{reference}, $params{report_id});
}

sub garden_waste_check_pending {
    my ($self, $report) = @_;


    if ( $report && ($report->get_extra_metadata('ddsubmitted') || 0) == 1 ) {
        return $report;
    }

    return undef;
}

sub garden_waste_dd_complete {
    my ($self, $report) = @_;
    $report->set_extra_metadata('ddsubmitted', 1);
    $report->update();
}

sub get_address_details_from_nlpg {
    my ( $self, $uprn_data) = @_;

    my $address;
    my $property = $uprn_data->{results}->[0]->{LPI};
    if ( $property ) {
        $address = {};
        my @namenumber = (_get_addressable_object($property, 'SAO'), _get_addressable_object($property, 'PAO'));
        $address->{address1} = join(", ", grep { /./ } map { FixMyStreet::Template::title($_) } @namenumber);
        $address->{address2} = FixMyStreet::Template::title($property->{STREET_DESCRIPTION});
        $address->{town} = FixMyStreet::Template::title($property->{TOWN_NAME});
        $address->{postcode} = $property->{POSTCODE_LOCATOR};
    }
    return $address;
}

sub _get_addressable_object {
    my ($property, $type) = @_;
    my $ao = $property->{$type . '_TEXT'} || '';
    $ao .= ' ' if $ao && $property->{$type . '_START_NUMBER'};
    $ao .= ($property->{$type . '_START_NUMBER'} || '') . ($property->{$type . '_START_SUFFIX'} || '');
    $ao .= '-' if $property->{$type . '_END_NUMBER'};
    $ao .= ($property->{$type . '_END_NUMBER'} || '') . ($property->{$type . '_END_SUFFIX'} || '');
    return $ao;
}

=head2 admin_templates_external_status_code_hook

In order to provide more nuanced messaging on the bin day page with regards to
not complete collections, the external status code admin is split into three
fields, which are then combined here for storage.

=cut

sub admin_templates_external_status_code_hook {
    my ($self) = @_;
    my $c = $self->{c};

    my $res_code = $c->get_param('resolution_code') || '';
    my $task_type = $c->get_param('task_type') || '';
    my $task_state = $c->get_param('task_state') || '';

    my $code = "$res_code,$task_type,$task_state";
    $code = '' if $code eq ',,';
    return $code;
}

=head2 Dashboard export

The CSV export includes all reports, including unconfirmed and hidden, and is
adapted in a few ways for Waste reports - including extra columns such as UPRN,
email/phone, payment amount and method.

=cut

# Include unconfirmed and hidden reports in CSV export
sub dashboard_export_include_all_states { 1 }

sub dashboard_export_problems_add_columns {
    my ($self, $csv) = @_;

    $csv->modify_csv_header( Detail => 'Address' );

    $csv->add_csv_columns(
        uprn => 'UPRN',
        user_email => 'User Email',
        user_phone => 'User Phone',
        payment_method => 'Payment method',
        payment_reference => 'Payment reference',
        payment => 'Payment',
        pro_rata => 'Pro rata payment',
        admin_fee => 'Admin fee',
        container => 'Subscription container',
        current_bins => 'Bin count declared',
        quantity => 'Subscription quantity',
    );

    $csv->objects_attrs({
        '+columns' => ['user.email', 'user.phone'],
        join => 'user',
    });

    $csv->csv_extra_data(sub {
        my $report = shift;

        my @fields = @{ $report->get_extra_fields() };
        my %fields = map { $_->{name} => $_->{value} } @fields;

        my $detail = $report->detail;
        $detail =~ s/^.*?\n\n//; # Remove waste category

        return {
            detail => $detail,
            uprn => $fields{uprn},
            user_name_display => $report->name,
            user_email => $report->user->email || '',
            user_phone => $report->user->phone || '',
            payment_method => $fields{payment_method} || '',
            payment_reference => $fields{PaymentCode} || $report->get_extra_metadata('chequeReference') || '',
            payment => $fields{payment},
            pro_rata => $fields{pro_rata},
            admin_fee => $fields{admin_fee},
            container => $fields{Subscription_Details_Containers},
            current_bins => $fields{current_containers},
            quantity => $fields{Subscription_Details_Quantity},
        };
    });
}



sub bulky_collection_window_days { 56 }

sub bulky_send_before_payment { 1 }

sub bulky_allowed_property {
    my ( $self, $property ) = @_;

    my $cfg = $self->feature('echo');

    return $self->bulky_enabled
        && grep { $_ == $property->{type_id} }
        @{ $cfg->{bulky_address_types} // [] };
}

sub collection_date {
    my ($self, $p) = @_;
    return $self->_bulky_date_to_dt($p->get_extra_field_value('Collection_Date'));
}

sub _bulky_cancellation_cutoff_date {
    my ($self, $collection_date) = @_;
    my $cutoff_time = $self->bulky_cancellation_cutoff_time();
    my $dt = $collection_date->clone->set(
        hour   => $cutoff_time->{hours},
        minute => $cutoff_time->{minutes},
    );
    return $dt;
}

sub _bulky_refund_cutoff_date {
    my ($self, $collection_dt) = @_;
    my $cutoff_dt = $collection_dt->clone->set(
        hour => 0, minute => 0,
    )->subtract( days => 2 );
    return $cutoff_dt;
}

sub bulky_free_collection_available { 0 }

sub bulky_hide_later_dates { 1 }

sub _bulky_date_to_dt {
    my ($self, $date) = @_;
    $date = (split(";", $date))[0];
    my $parser = DateTime::Format::Strptime->new( pattern => '%FT%T', time_zone => FixMyStreet->local_time_zone);
    my $dt = $parser->parse_datetime($date);
    return $dt ? $dt->truncate( to => 'day' ) : undef;
}

sub waste_munge_bulky_data {
    my ($self, $data) = @_;

    my $c = $self->{c};
    my ($date, $ref, $expiry) = split(";", $data->{chosen_date});

    my $guid_key = $self->council_url . ":echo:bulky_event_guid:" . $c->stash->{property}->{id};
    $data->{extra_GUID} = $self->{c}->session->{$guid_key};
    $data->{extra_reservation} = $ref;

    $data->{title} = "Bulky goods collection";
    $data->{detail} = "Address: " . $c->stash->{property}->{address};
    $data->{category} = "Bulky collection";
    $data->{extra_Collection_Date} = $date;
    $data->{extra_Exact_Location} = $data->{location};

    my $first_date = $self->{c}->session->{first_date_returned};
    my $dt = DateTime::Format::W3CDTF->parse_datetime($date);
    $data->{'extra_First_Date_Returned_to_Customer'} = $dt->strftime("%d/%m/%Y");
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
    $data->{extra_Payment_Details_Payment_Amount} = $self->bulky_total_cost($data);
}

sub waste_reconstruct_bulky_data {
    my ($self, $p) = @_;

    my $saved_data = {
        "chosen_date" => $p->get_extra_field_value('Collection_Date'),
        "location" => $p->get_extra_field_value('Exact_Location'),
        "location_photo" => $p->get_extra_metadata("location_photo"),
    };

    my @items_list = @{ $self->bulky_items_master_list };
    my %items = map { $_->{bartec_id} => $_->{name} } @items_list;

    my @fields = split /::/, $p->get_extra_field_value('Bulky_Collection_Bulky_Items');
    my @notes = split /::/, $p->get_extra_field_value('Bulky_Collection_Notes');
    for my $id (1..@fields) {
        $saved_data->{"item_$id"} = $items{$fields[$id-1]};
        $saved_data->{"item_notes_$id"} = $notes[$id-1];
        $saved_data->{"item_photo_$id"} = $p->get_extra_metadata("item_photo_$id");
    }

    return $saved_data;
}

### Stub until https://github.com/mysociety/societyworks/issues/3761 is implemented
sub bulky_cancellation_report { 0 };

1;
