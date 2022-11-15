package FixMyStreet::Roles::CobrandEcho;

use strict;
use warnings;
use Moo::Role;
use Sort::Key::Natural qw(natkeysort_inplace);
use FixMyStreet::DateRange;
use FixMyStreet::WorkingDays;
use Open311::GetServiceRequestUpdates;

=head1 NAME

FixMyStreet::Roles::CobrandEcho - shared code between cobrands using an Echo backend

=cut

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
    if ($self->moniker eq 'bromley') {
        natkeysort_inplace { $_->{label} } @$data;
    }
    return $data;
}

sub look_up_property {
    my ($self, $id) = @_;

    my $cfg = $self->feature('echo');
    my $echo = Integrations::Echo->new(%$cfg);
    my $calls = $echo->call_api($self->{c}, $self->moniker,
        "look_up_property:$id",
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

sub available_bin_services_for_address {
    my ($self, $property) = @_;

    my $services = $self->{c}->stash->{services};
    return {} unless keys %$services;

    my $available_services = {};
    for my $service ( values %$services ) {
        my $name = $service->{service_name};
        $name =~ s/ /_/g;
        $available_services->{$name} = {
            service_id => $service->{service_id},
            is_active => 1,
        };
    }

    return $available_services;
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
            next if $end && $end < $today && $service_name ne 'Garden Waste';
            $last_date = $end;
            $current = $task;
        }
    }
    return $current;
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
            $description = $schedule->{ScheduleDescription} if $desc_to_use eq 'schedule';
        }

        next if $start_date gt $today; # Shouldn't have a LastInstance in this case, but some bad data

        my $last = $schedule->{LastInstance};
        $d = construct_bin_date($last->{CurrentScheduledDate});
        # It is possible the last instance for this schedule has been rescheduled to
        # be in the future. If so, we should treat it like it is a next instance.
        if ($d && $d->strftime("%F") gt $today && (!$min_next || $d < $min_next->{date})) {
            $min_next = _schedule_object($last, $d);
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
            })->first;
            $resolution = $template->text if $template;
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
        if ($state eq 'Not Completed' || ($state eq 'Completed' && $orig_resolution eq 'Excess Waste')) {
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

        my $event = $cfg->{echo}->GetEvent($report->external_id);
        my $request = $self->construct_waste_open311_update($cfg, $event) or next;

        next if !$request->{status} || $request->{status} eq 'confirmed'; # Still in initial state
        next unless $self->waste_check_last_update(
            $cfg, $report, $request->{status}, $request->{external_status_code});

        my $last_updated = construct_bin_date($event->{LastUpdatedDate});
        $request->{comment_time} = $last_updated;

        print "  Updating report to state $request->{status}, $request->{description} ($request->{external_status_code})\n" if $cfg->{verbose};
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
    return {
        description => $description,
        status => $status,
        update_id => 'waste',
        external_status_code => $resolution_id ? "$resolution_id,," : "",
        prefer_template => 1,
    };
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



1;
