package FixMyStreet::Roles::CobrandEcho;

use strict;
use warnings;
use DateTime;
use DateTime::Format::Strptime;
use Moo::Role;
use Sort::Key::Natural qw(natkeysort_inplace);
use FixMyStreet::DateRange;
use FixMyStreet::WorkingDays;
use Open311::GetServiceRequestUpdates;

=head1 NAME

FixMyStreet::Roles::CobrandEcho - shared code between cobrands using an Echo backend

=cut

sub bin_day_format { '%A, %-d~~~ %B' }

sub bin_addresses_for_postcode {
    my $self = shift;
    my $pc = shift;

    my $cfg = $self->feature('echo');
    my $echo = Integrations::Echo->new(%$cfg);
    my $points = $echo->FindPoints($pc, $cfg);
    my $data = [ map { {
        value => $_->{Id},
        label => FixMyStreet::Template::title($_->{Description}),
    } } @$points ];
    natkeysort_inplace { $_->{label} } @$data;
    return $data;
}

sub look_up_property {
    my ($self, $id) = @_;

    my $cfg = $self->feature('echo');
    my $echo = Integrations::Echo->new(%$cfg);
    my $calls = $echo->call_api($self->{c}, $self->moniker,
        "look_up_property:$id",
        1,
        GetPointAddress => [ $id ],
        GetServiceUnitsForObject => [ $id ],
        GetEventsForObject => [ 'PointAddress', $id ],
    );

    $self->{api_serviceunits} = $calls->{"GetServiceUnitsForObject $id"};
    $self->{api_events} = $calls->{"GetEventsForObject PointAddress $id"};
    my $result = $calls->{"GetPointAddress $id"};
    return {
        id => $result->{Id},
        uprn => $result->{SharedRef}{Value}{anyType},
        address => FixMyStreet::Template::title($result->{Description}),
        latitude => $result->{Coordinates}{GeoPoint}{Latitude},
        longitude => $result->{Coordinates}{GeoPoint}{Longitude},
    };
}

my %irregulars = ( 1 => 'st', 2 => 'nd', 3 => 'rd', 11 => 'th', 12 => 'th', 13 => 'th');
sub ordinal {
    my $n = shift;
    $irregulars{$n % 100} || $irregulars{$n % 10} || 'th';
}

sub construct_bin_date {
    my $str = shift;
    return unless $str;
    my $offset = ($str->{OffsetMinutes} || 0) * 60;
    my $zone = DateTime::TimeZone->offset_as_string($offset);
    my $date = DateTime::Format::W3CDTF->parse_datetime($str->{DateTime});
    $date->set_time_zone($zone);
    return $date;
}

sub _get_service_tasks {
    my ($self, $service) = @_;

    my $servicetasks = Integrations::Echo::force_arrayref($service->{ServiceTasks}, 'ServiceTask');
    @$servicetasks = grep { $_->{ServiceTaskSchedules} } @$servicetasks;
    return $servicetasks;
}

sub _get_current_service_task {
    my ($self, $service) = @_;

    my $servicetasks = $self->_get_service_tasks($service);
    return unless @$servicetasks;

    my $service_name = $self->service_name_override($service);
    my $today = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);
    my ($current, $last_date);
    foreach my $task ( @$servicetasks ) {
        my $schedules = Integrations::Echo::force_arrayref($task->{ServiceTaskSchedules}, 'ServiceTaskSchedule');
        foreach my $schedule ( @$schedules ) {
            my $end = construct_bin_date($schedule->{EndDate});

            next if $last_date && $end && $end < $last_date;
            next if $end && $end < $today && $service_name !~ /Garden Waste/i;
            $last_date = $end;
            $current = $task;
        }
    }
    return $current;
}

sub missed_event_types {}

sub _closed_event {
    my ($self, $event) = @_;
    return 1 if $event->{ResolvedDate};
    return 0;
}

sub _parse_events {
    my $self = shift;
    my $events_data = shift;
    my $events = {};
    my $missed_event_types = $self->missed_event_types;
    foreach (@$events_data) {
        my $event_type = $_->{EventTypeId};
        my $type = $missed_event_types->{$event_type} || 'enquiry';

        # Only care about open requests/enquiries
        my $closed = $self->_closed_event($_);
        next if $type ne 'missed' && $type ne 'bulky' && $closed;
        next if $type eq 'bulky' && !$closed;

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
            $self->parse_event_missed($_, $closed, $events);
        } elsif ($type eq 'bulky') {
            my $report = $self->problems->search({ external_id => $_->{Guid} })->first;
            my $resolved_date = construct_bin_date($_->{ResolvedDate});
            $events->{enquiry}->{$event_type} = {
                date => $resolved_date,
                report => $report,
                resolution => $_->{ResolutionCodeId},
                state => $_->{EventStateId},
            };
        } else { # General enquiry of some sort
            $events->{enquiry}->{$event_type} = 1;
        }
    }
    return $events;
}

sub parse_event_missed {
    my ($self, $event, $closed, $events) = @_;
    my $report = $self->problems->search({ external_id => $event->{Guid} })->first;
    my $service_id = $event->{ServiceId};
    my $data = {
        closed => $closed,
        date => construct_bin_date($event->{EventDate}),
    };
    $data->{report} = $report if $report;
    push @{$events->{missed}->{$service_id}}, $data;
}

sub _events_since_date {
    my ($self, $last_date, $events) = @_;
    my @since_events = grep { $_->{date} >= $last_date } @$events;
    my @closed = grep { $_->{closed} } @since_events;
    my @open = grep { !$_->{closed} } @since_events;
    return {
        @open ? (open => $open[0]) : (),
        @closed ? (closed => $closed[0]) : (),
    };
}

sub _schedule_object {
    my ($instance, $current) = @_;
    my $original = construct_bin_date($instance->{OriginalScheduledDate});
    my $changed = $current->strftime("%F") ne $original->strftime("%F");
    return {
        date => $current,
        ordinal => ordinal($current->day),
        changed => $changed,
        ref => $instance->{Ref}{Value}{anyType},
    };
}

sub _parse_schedules {
    my $servicetask = shift;
    my $desc_to_use = shift || 'schedule';
    my $schedules = Integrations::Echo::force_arrayref($servicetask->{ServiceTaskSchedules}, 'ServiceTaskSchedule');

    my $today = DateTime->now->set_time_zone(FixMyStreet->local_time_zone)->strftime("%F");
    my ($min_next, $max_last, $description, $max_end_date);

    if ($desc_to_use eq 'task') {
        $description = $servicetask->{ScheduleDescription};
    }

    foreach my $schedule (@$schedules) {
        my $start_date = construct_bin_date($schedule->{StartDate})->strftime("%F");
        my $end_date = construct_bin_date($schedule->{EndDate})->strftime("%F");
        $max_end_date = $end_date if !defined($max_end_date) || $max_end_date lt $end_date;

        next if $end_date lt $today;

        my $next = $schedule->{NextInstance};
        my $d = construct_bin_date($next->{CurrentScheduledDate});
        $d = undef if $d && $d->strftime('%F') lt $start_date; # Shouldn't happen
        if ($d && (!$min_next || $d < $min_next->{date})) {
            $min_next = _schedule_object($next, $d);
            $min_next->{schedule} = $schedule;
            $description = $schedule->{ScheduleDescription} if $desc_to_use eq 'schedule';
        }

        next if $start_date gt $today; # Shouldn't have a LastInstance in this case, but some bad data

        my $last = $schedule->{LastInstance};
        $d = construct_bin_date($last->{CurrentScheduledDate});
        # It is possible the last instance for this schedule has been rescheduled to
        # be in the future. If so, we should treat it like it is a next instance.
        if ($d && $d->strftime("%F") gt $today && (!$min_next || $d < $min_next->{date})) {
            $min_next = _schedule_object($last, $d);
            $min_next->{schedule} = $schedule;
            $description = $schedule->{ScheduleDescription} if $desc_to_use eq 'schedule';
        } elsif ($d && (!$max_last || $d > $max_last->{date})) {
            $max_last = _schedule_object($last, $d);
        }
    }

    return {
        next => $min_next,
        last => $max_last,
        description => $description,
        end_date => $max_end_date,
    };
}

sub waste_task_resolutions {
    my ($self, $tasks, $task_ref_to_row) = @_;

    return unless $task_ref_to_row;

    my $now = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);
    foreach (@$tasks) {
        my $ref = join(',', @{$_->{Ref}{Value}{anyType}});
        my $completed = construct_bin_date($_->{CompletedDate});
        my $state = $_->{State}{Name} || '';
        my $task_type_id = $_->{TaskTypeId} || '';

        my $orig_resolution = $_->{Resolution}{Name} || '';
        my $resolution = $orig_resolution;
        my $resolution_id = $_->{Resolution}{Ref}{Value}{anyType};
        if ($resolution_id) {
            my $template = FixMyStreet::DB->resultset('ResponseTemplate')->search({
                'me.body_id' => $self->body->id,
                'contact.category' => [ 'Report missed collection', undef ],
                'me.external_status_code' => [
                    "$resolution_id,$task_type_id,$state",
                    "$resolution_id,$task_type_id,",
                    "$resolution_id,,$state",
                    "$resolution_id,,",
                    $resolution_id,
                ],
            }, {
                # Order by descending length so more specific
                # external_status_codes match over less specific
                order_by => \'length(me.external_status_code) desc',
                join => { 'contact_response_templates' => 'contact' },
            })->first;
            $resolution = $template->text if $template;
        }

        if (($resolution_id || 0) == 237 && $state eq 'Completed') { # Echo returning bad data
            $resolution = '';
        }

        my $row = $task_ref_to_row->{$ref};
        $row->{last}{state} = $state unless $state eq 'Completed' || $state eq 'Not Completed' || $state eq 'Outstanding' || $state eq 'Allocated';
        $row->{last}{completed} = $completed;
        $row->{last}{resolution} = $resolution;

        # Special handling if last instance is today e.g. if it's before a
        # particular hour and outstanding, show it as in progress
        if ($row->{last}{date}->ymd eq $now->ymd) {
            $self->waste_on_the_day_criteria($completed, $state, $now, $row);
        }

        # If the task is ended and could not be done, do not allow reporting
        if ($state eq 'Not Completed' || ($state eq 'Completed' && $orig_resolution =~ /Excess/)) {
            $row->{report_allowed} = 0;
            $row->{report_locked_out} = 1;
        }
    }
}

sub bin_future_collections {
    my $self = shift;

    my $services = $self->{c}->stash->{service_data};
    my @tasks;
    my %names;
    foreach (@$services) {
        push @tasks, $_->{service_task_id};
        $names{$_->{service_task_id}} = $_->{service_name};
    }

    my $echo = $self->feature('echo');
    $echo = Integrations::Echo->new(%$echo);
    my $result = $echo->GetServiceTaskInstances(@tasks);

    my $events = [];
    foreach (@$result) {
        my $task_id = $_->{ServiceTaskRef}{Value}{anyType};
        my $tasks = Integrations::Echo::force_arrayref($_->{Instances}, 'ScheduledTaskInfo');
        foreach (@$tasks) {
            my $dt = construct_bin_date($_->{CurrentScheduledDate});
            my $summary = $names{$task_id} . ' collection';
            my $desc = '';
            push @$events, { date => $dt, summary => $summary, desc => $desc };
        }
    }
    return $events;
}

=item waste_fetch_events

Loop through all open waste events to see if there have been any updates

=back

=cut

sub waste_fetch_events {
    my ($self, $params) = @_;

    my $body = $self->body;
    my $conf;
    my $report_params = {};
    if ($params->{devolved}) {
        my @contacts = $body->contacts->search({
            send_method => 'Open311',
            endpoint => { '!=', '' },
        })->all;
        die "Could not find any devolved contacts\n" unless @contacts;
        $conf = $contacts[0];
        $report_params = { category => [ map { $_->category } @contacts ] };
    } elsif ($self->moniker eq 'brent') {
        $conf = $body;
        $report_params = { external_id => { like => 'Echo%' } };
    } else {
        $conf = $body;
    }

    my %open311_conf = (
        endpoint => $conf->endpoint || '',
        api_key => $conf->api_key || '',
        jurisdiction => $conf->jurisdiction || '',
        extended_statuses => $body->send_extended_statuses,
    );
    my $cobrand = $body->get_cobrand_handler;
    $cobrand->call_hook(open311_config_updates => \%open311_conf)
        if $cobrand;
    my $open311 = Open311->new(%open311_conf);

    my $suppress_alerts = $self->moniker eq 'sutton' ? 1 : 0;
    my $updates = Open311::GetServiceRequestUpdates->new(
        current_open311 => $open311,
        current_body => $body,
        system_user => $body->comment_user,
        suppress_alerts => $suppress_alerts,
        blank_updates_permitted => $body->blank_updates_permitted,
    );

    my $echo = $self->feature('echo');
    $echo = Integrations::Echo->new(%$echo);

    my $cfg = {
        verbose => $params->{verbose},
        updates => $updates,
        echo => $echo,
        event_types => {},
    };

    my $reports = $self->problems->search({
        external_id => { '!=', '' },
        state => [ FixMyStreet::DB::Result::Problem->open_states() ],
        # TODO Should know which categories to use somehow, even in non-devolved case
        %$report_params,
    });

    while (my $report = $reports->next) {
        print 'Fetching data for report ' . $report->id . "\n" if $cfg->{verbose};

        (my $external_id = $report->external_id) =~ s/^Echo-//;
        my $event = $cfg->{echo}->GetEvent($external_id);
        my $request = $self->construct_waste_open311_update($cfg, $event) or next;

        next if !$request->{status} || $request->{status} eq 'confirmed'; # Still in initial state
        next unless $self->waste_check_last_update(
            $cfg, $report, $request->{status}, $request->{external_status_code});

        my $last_updated = construct_bin_date($event->{LastUpdatedDate});
        $request->{comment_time} = $last_updated;

        print "  Updating report to state $request->{status}, $request->{description} ($request->{external_status_code})\n" if $cfg->{verbose};
        if ($cobrand->moniker eq 'brent') {
            $cfg->{updates}->suppress_alerts($event->{EventTypeId} == 1159 ? 1 : 0);
        }
        $cfg->{updates}->process_update($request, $report);
    }
}

sub construct_waste_open311_update {
    my ($self, $cfg, $event) = @_;

    return undef unless $event;
    my $event_type = $cfg->{event_types}{$event->{EventTypeId}} ||= $self->waste_get_event_type($cfg, $event->{EventTypeId});
    my $state_id = $event->{EventStateId};
    my $resolution_id = $event->{ResolutionCodeId} || '';
    my $status = $event_type->{states}{$state_id}{state};
    my $description = $event_type->{resolution}{$resolution_id} || $event_type->{states}{$state_id}{name};
    my $external_status_code;
    if ($self->moniker eq "brent") {
        $external_status_code = $resolution_id ? "$resolution_id" : "",
    } else {
        $external_status_code = $resolution_id ? "$resolution_id,," : "",
    }
    return {
        description => $description,
        status => $status,
        update_id => 'waste',
        external_status_code => $external_status_code,
        prefer_template => 1,
    }
}

sub waste_get_event_type {
    my ($self, $cfg, $id) = @_;

    my $event_type = $cfg->{echo}->GetEventType($id);

    my $state_map = $self->waste_event_state_map;

    my $states = Integrations::Echo::force_arrayref($event_type->{Workflow}->{States}, 'State');
    my $data;
    foreach (@$states) {
        my $core = $_->{CoreState}; # New/Pending/Closed
        my $name = $_->{Name}; # New : Unallocated/Allocated to Crew : Completed/Not Completed/Rejected/Closed
        $name =~ s/ +$//;
        $data->{states}{$_->{Id}} = {
            core => $core,
            name => $name,
            state => $state_map->{$core}{$name},
        };
        my $codes = Integrations::Echo::force_arrayref($_->{ResolutionCodes}, 'StateResolutionCode');
        foreach (@$codes) {
            my $name = $_->{Name};
            my $id = $_->{ResolutionCodeId};
            $data->{resolution}{$id} = $name;
        }
    }
    return $data;
}

# We only have the report's current state, no history, so must check current
# against latest received update to see if state the same, and skip if so
sub waste_check_last_update {
    my ($self, $cfg, $report, $status, $resolution_id) = @_;

    my $latest = $report->comments->search(
        { external_id => 'waste', },
        { order_by => { -desc => 'id' } }
    )->first;

    if ($latest) {
        my $state = $cfg->{updates}->current_open311->map_state($status);
        my $code = $latest->get_extra_metadata('external_status_code') || '';
        if ($latest->problem_state eq $state && $code eq $resolution_id) {
            print "  Latest update matches fetched state, skipping\n" if $cfg->{verbose};
            return;
        }
    }
    return 1;
}

sub waste_get_next_dd_day {
    my ($self, $payment_type) = @_;

    # new DD mandates must have a 10-day wait
    my $dd_delay = 10;

    # ad-hoc payments on an existing mandate only need a 5-day wait
    if ($payment_type && ($payment_type eq 'ad-hoc')) { $dd_delay = 5; }

    my $dt = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);
    my $wd = FixMyStreet::WorkingDays->new(public_holidays => FixMyStreet::Cobrand::UK::public_holidays());

    my $next_day = $wd->add_days( $dt, $dd_delay );

    return $next_day;
}

sub waste_sub_due {
    my ($self, $date) = @_;

    my $now = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);
    my $sub_end = DateTime::Format::W3CDTF->parse_datetime($date);

    my $diff = $now->delta_days($sub_end)->in_units('days');
    return $diff <= $self->garden_due_days;
}

sub waste_sub_overdue {
    my ($self, $date, $interval, $count) = @_;

    my $now = DateTime->now->set_time_zone(FixMyStreet->local_time_zone)->truncate( to => 'day' );
    my $sub_end = DateTime::Format::W3CDTF->parse_datetime($date)->truncate( to => 'day' );

    if ( $now > $sub_end ) {
        my $diff = 1;
        if ( $interval ) {
            $diff = $now->delta_days($sub_end)->in_units($interval) < $count;
        }
        return $diff;
    };

    return 0;
}

sub _get_cost_from_array {
    my ($self, $costs) = @_;

    my $now = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);
    my @sorted = sort { $b->{start_date} cmp $a->{start_date} } @$costs;
    foreach my $cost (@sorted) {
        return $cost->{cost} if $cost->{start_date} le $now->strftime('%Y-%m-%d %H:%M')
    }

    die("Couldn't find a valid cost item");
}

sub garden_waste_sacks_cost_pa {
    my ($self) = @_;
    my $cost = $self->feature('payment_gateway')->{ggw_sacks_cost};

    if (ref $cost eq 'ARRAY') {
        $cost = $self->_get_cost_from_array($cost);
    }

    return $cost;
}

sub garden_waste_cost_pa {
    my ($self, $bin_count) = @_;

    $bin_count ||= 1;

    my $per_bin_cost = $self->feature('payment_gateway')->{ggw_cost};

    if (ref $per_bin_cost eq 'ARRAY') {
        $per_bin_cost = $self->_get_cost_from_array($per_bin_cost);
    }

    my $cost = $per_bin_cost * $bin_count;
    return $cost;
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

sub bulky_check_missed_collection {
    my ($self, $events, $blocked_codes) = @_;

    my $cfg = $self->feature('echo');
    my $service_id = $cfg->{bulky_service_id} or return;
    my $event_type_id = $cfg->{bulky_event_type_id} or return;
    my $event = $events->{enquiry}{$event_type_id};
    return unless $event;
    my $row = {
        service_name => 'Bulky waste',
        service_id => $service_id,
    };
    my $in_time = $self->within_working_days($event->{date}, 2);
    foreach my $state_id (keys %$blocked_codes) {
        next unless $event->{state} eq $state_id;
        foreach (keys %{$blocked_codes->{$state_id}}) {
            if ($event->{resolution} eq $_ || $_ eq 'all') {
                $row->{report_locked_out} = 1;
                $row->{report_locked_out_reason} = $blocked_codes->{$state_id}{$_};
            }
        }
    }
    $row->{report_allowed} = $in_time && !$row->{report_locked_out};

    my $missed_events = $events->{missed}->{$service_id} || [];
    my $recent_events = $self->_events_since_date($event->{date}, $missed_events);
    $row->{report_open} = $recent_events->{open} || $recent_events->{closed};
    $self->{c}->stash->{bulky_missed} = $row;
}

sub find_available_bulky_slots {
    my ( $self, $property, $last_earlier_date_str, $no_cache ) = @_;

    my $key
        = $self->council_url . ":echo:available_bulky_slots:"
        . ( $last_earlier_date_str ? 'later' : 'earlier' ) . ':'
        . $property->{id};
    return $self->{c}->session->{$key}
        if $self->{c}->session->{$key} && !$no_cache;

    my $cfg = $self->feature('echo');
    my $echo = Integrations::Echo->new(%$cfg);

    my $service_id = $cfg->{bulky_service_id};
    my $event_type_id = $cfg->{bulky_event_type_id};

    my $guid_key = $self->council_url . ":echo:bulky_event_guid:" . $property->{id};
    my $guid = $self->{c}->session->{$guid_key};
    unless ($guid) {
        require UUID::Tiny;
        $self->{c}->session->{$guid_key} = $guid = UUID::Tiny::create_uuid_as_string();
    }

    my $window = $self->_bulky_collection_window($last_earlier_date_str);
    my @available_slots;
    my $slots = $echo->ReserveAvailableSlotsForEvent($service_id, $event_type_id, $property->{id}, $guid, $window->{date_from}, $window->{date_to});
    foreach (@$slots) {
        push @available_slots, {
            date => construct_bin_date($_->{StartDate}),
            reference => $_->{Reference},
            expiry => construct_bin_date($_->{Expiry}),
        };
    }

    $self->{c}->session->{$key} = \@available_slots if !$no_cache;

    return \@available_slots;
}

sub check_bulky_slot_available {
    my ( $self, $chosen_date_string, %args ) = @_;

    my $form = $args{form};

    # chosen_date_string is of the form
    # '2023-08-29T00:00:00;AS3aUwCS7NwGCTIzMDMtMTEwMTyNVqC8SCJe+A==;2023-08-25T15:49:38'
    my ( $collection_date, undef, $slot_expiry_date )
        = $chosen_date_string =~ /[^;]+/g;

    my $parser = DateTime::Format::Strptime->new( pattern => '%FT%T' );
    my $slot_expiry_dt = $parser->parse_datetime($slot_expiry_date);

    my $now_dt = DateTime->now;

    # Note: Both $slot_expiry_dt and $now_dt are UTC
    if ( $slot_expiry_dt <= $now_dt ) {
        # Call ReserveAvailableSlots again, try to get
        # the same collection date
        my $available_slots = $self->find_available_bulky_slots(
            $self->{c}->stash->{property}, undef, 'no_cache' );

        my ($slot) = grep { $_->{date} eq $collection_date } @$available_slots;

        if ($slot) {
            $form->saved_data->{chosen_date}
                = $slot->{date} . ";"
                . $slot->{reference} . ";"
                . $slot->{expiry};

            return 1;
        } else {
            return 0;
        }
    } else {
        return 1;
    }
}

sub save_item_names_to_report {
    my ($self, $data) = @_;

    my $report = $self->{c}->stash->{report};
    foreach (grep { /^item_(notes_)?\d/ } keys %$data) {
        $report->set_extra_metadata($_ => $data->{$_}) if $data->{$_};
    }
}

sub bulky_nice_item_list {
    my ($self, $report) = @_;

    my @item_nums = map { /^item_(\d+)/ } grep { /^item_\d/ } keys %{$report->get_extra_metadata};
    my @items = sort { $a <=> $b } @item_nums;

    my @fields;
    for my $item (@items) {
        if (my $value = $report->get_extra_metadata("item_$item")) {
            if (my $note = $report->get_extra_metadata("item_notes_$item")) {
                $value .= " ($note)";
            }
            push @fields, $value;
        }
    }
    my $items_extra = $self->bulky_items_extra(exclude_pricing => 1);

    return [
        map {
            value => $_,
            message => $items_extra->{$_}{message},
        },
        @fields,
    ];
}

1;
