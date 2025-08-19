package FixMyStreet::Roles::Cobrand::Echo;

use v5.14;
use warnings;
use DateTime;
use DateTime::Format::Strptime;
use List::Util qw(min);
use Moo::Role;
use Path::Tiny;
use POSIX qw(floor);
# use Sort::Key::Natural qw(natkeysort_inplace);
use FixMyStreet::DateRange;
use FixMyStreet::DB;
use FixMyStreet::WorkingDays;
use Open311::GetServiceRequestUpdates;
use Integrations::Echo::Events;

with 'FixMyStreet::Roles::EnforcePhotoSizeOpen311PreSend';

requires 'waste_containers';
requires 'waste_service_to_containers';
requires 'waste_extra_service_info';

requires 'garden_subscription_event_id';
requires 'garden_echo_container_name';
requires 'garden_container_data_extract';
requires 'garden_due_days';
requires 'garden_service_id';

requires 'waste_bulky_missed_blocked_codes';

=head1 NAME

FixMyStreet::Roles::Cobrand::Echo - shared code between cobrands using an Echo backend

=head2 waste_check_downtime

Echo has regular periods of scheduled downtime; we record these
in a file and check it here to show appropriate messaging.

=cut

sub waste_check_downtime {
    my $self = shift;
    my $c = $self->{c};

    my $result = $self->waste_check_downtime_file;
    if ($result->{state} eq 'down') {
        $c->stash->{title} = 'Planned maintenance';
        $c->stash->{header_class} = 'blank';
        $c->response->header('X-Custom-Error-Provided' => 'yes');
        $c->detach('/page_error', [ $result->{message}, 503 ]);
    } elsif ($result->{state} eq 'upcoming') {
        $c->stash->{site_message_upcoming_downtime} = $result->{message}
    }
}

sub waste_check_downtime_file {
    my $self = shift;

    my $parser = DateTime::Format::W3CDTF->new;
    my $now = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);

    my $cfg = $self->feature('echo');
    my $downtime_csv = $cfg->{downtime_csv};
    my @lines = eval { path(FixMyStreet->path_to($downtime_csv))->lines({ chomp => 1 }) };
    foreach (@lines) {
        my ($start, $end, $message) = split /,/;
        ($start, $end) = map { eval { $parser->parse_datetime($_) } } ($start, $end);
        next unless $start && $end && $start < $end;
        my $start_hour = $start->strftime('%l%P');
        my $end_hour = $end->strftime('%l%P');

        if ($message && $message eq '1') {
            $message = "Our waste service system is temporarily unavailable. This also affects our Contact Centre, as they are unable to access or update information at this time. Please refrain from calling until the system is restored. We apologise for any inconvenience and appreciate your patience.";
        } elsif (!$message) {
            $message = "Due to planned maintenance, this waste service will be unavailable from $start_hour until $end_hour.";
            $end->add( minutes => 15 ); # Add a buffer, sometimes they go past their end time
        }

        if ($now >= $start && $now < $end) {
            $message .= " Please accept our apologies for the disruption and try again later.";
            return { state => 'down', message => $message };
        }

        my $start_warning = $start->clone->subtract( hours => 2 );
        if ($now >= $start_warning && $now < $start) {
            return { state => 'upcoming', message => $message };
        }
    }
    return { state => 'up' };
}

sub bin_day_format { '%A, %-d~~~ %B' }

sub bin_addresses_for_postcode {
    my $self = shift;
    my $pc = shift;

    my $cfg = $self->feature('echo');
    my $echo = Integrations::Echo->new(%$cfg);
    my $points = $echo->FindPoints($pc);
    my $data = [ map { {
        value => $_->{Id},
        label => FixMyStreet::Template::title($_->{Description}),
    } } @$points ];
    # natkeysort_inplace { $_->{label} } @$data;
    return $data;
}

sub _allow_async_echo_lookup {
    my $self = shift;
    my $action = $self->{c}->action;
    return 0 if $action eq 'waste/pay_retry' || $action eq 'waste/direct_debit_error' || $action eq 'waste/calendar_ics' || $action eq 'waste/garden/transfer';
    return 1;
}

sub look_up_property {
    my ($self, $id) = @_;

    my $cfg = $self->feature('echo');
    my $echo = Integrations::Echo->new(%$cfg);
    my $background = $self->_allow_async_echo_lookup;
    my $calls = $echo->call_api($self->{c}, $self->moniker,
        "look_up_property:$id",
        $background,
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
        type_id => $result->{PointAddressType}{Id},
        type_name => $result->{PointAddressType}{Name},
    };
}

sub bin_services_for_address {
    my ($self, $property) = @_;

    $self->{c}->stash->{containers} = $self->waste_containers;

    my %service_to_containers = $self->waste_service_to_containers;
    my %request_allowed = map { $_ => 1 } keys %service_to_containers;

    my $quantities = $self->{c}->stash->{quantities} = {};

    my $result = $self->{api_serviceunits};
    $self->waste_extra_service_info_all_results($property, $result);
    return [] unless @$result;

    my $events = $self->_parse_events($self->{api_events});

    # If there is an open Garden subscription event, assume
    # that means a bin is being delivered and so a pending subscription
    if ($events->filter({ event_type => $self->garden_subscription_event_id, closed => 0 })) {
        $self->{c}->stash->{pending_subscription} = { title => 'Garden Subscription - New' };
        $self->{c}->stash->{open_garden_event} = 1;
    }

    # Bulky/small items collection event
    my $waste_cfg = $self->{c}->stash->{waste_features};
    if ($waste_cfg && $waste_cfg->{bulky_missed}) {
        $self->bulky_check_missed_collection($events, $self->waste_bulky_missed_blocked_codes);
    }

    my @to_fetch;
    my @task_refs;
    my @rows = $self->waste_relevant_serviceunits($result);
    # Each row is normally a service unit but e.g. SLWP has multiple rows per
    # service unit and we only want to call GetEventsForObject once with each
    # service unit
    my %seen_service_units;
    foreach (@rows) {
        my $schedules = $_->{Schedules};
        $_->{expired} = 1 if $self->waste_sub_overdue( $schedules->{end_date}, weeks => 4 );

        next unless $schedules->{next} or $schedules->{last};
        $_->{active} = 1;
        push @to_fetch, GetEventsForObject => [ ServiceUnit => $_->{Id} ]
            unless $seen_service_units{$_->{Id}}++;
        push @task_refs, $schedules->{last}{ref} if $schedules->{last};
    }
    push @to_fetch, GetTasks => \@task_refs if @task_refs;

    $self->waste_extra_service_info($property, @rows);

    my $cfg = $self->feature('echo');
    my $echo = Integrations::Echo->new(%$cfg);
    my $background = $self->_allow_async_echo_lookup;
    my $calls = $echo->call_api($self->{c}, $self->moniker,
        'bin_services_for_address:' . $property->{id},
        $background, @to_fetch);

    if ($self->can('bulky_enabled')) {
        $property->{show_bulky_waste} = $self->bulky_allowed_property($property);
    }

    my @out;
    my %task_ref_to_row;
    foreach (@rows) {
        my $service_id = $_->{ServiceId};
        my $service_name = $self->service_name_override($_);
        next unless $_->{active} || ( lc($service_name) eq 'garden waste' && $_->{expired} );

        my $schedules = $_->{Schedules};
        my $servicetask = $_->{ServiceTask};

        my ($containers, $request_max) = $self->call_hook(waste_service_containers => $_);
        if ($service_to_containers{$service_id}) {
            $containers ||= $service_to_containers{$service_id}{containers};
            $request_max ||= $service_to_containers{$service_id}{max};
        }

        my $open_requests = { map { $_->{container} => $_ } $events->filter({ type => 'request', containers => $containers })->list };
        $self->call_hook(waste_munge_bin_services_open_requests => $open_requests);

        my $garden = 0;
        my $garden_bins;
        my $garden_sacks;
        my $garden_container;
        my $garden_cost = 0;
        my $garden_due;
        my $garden_overdue = 0;
        my $garden_container_end_date; # Containers may be changing whilst subscription already renewed
        if (lc($service_name) eq 'garden waste') {
            $garden = 1;
            $garden_due = $self->waste_sub_due($schedules->{end_date});
            $garden_overdue = $schedules if $_->{expired};
            if ($self->moniker eq 'sutton' || $self->moniker eq 'kingston') {
                my $data = Integrations::Echo::force_arrayref($servicetask->{ServiceTaskLines}, 'ServiceTaskLine');
                ($garden_bins, $garden_sacks, $garden_cost, $garden_container, $garden_container_end_date) = $self->garden_container_data_extract($data, $containers, $quantities, $schedules);
            } else {
                my $data = Integrations::Echo::force_arrayref($servicetask->{Data}, 'ExtensibleDatum');
                foreach (@$data) {
                    next unless $_->{DatatypeName} eq $self->garden_echo_container_name;
                    ($garden_bins, $garden_sacks, $garden_cost, $garden_container) = $self->garden_container_data_extract($_, $containers, $quantities, $schedules);
                }
            }
            $request_max = $garden_bins;

            if ($self->{c}->stash->{waste_features}->{garden_disabled}) {
                $garden = 0;
            }
        }

        my $request_allowed = ($request_allowed{$service_id} || !%service_to_containers) && $request_max && $schedules->{next};
        my $row = {
            id => $_->{Id},
            service_id => $service_id,
            service_name => $service_name,
            garden_waste => $garden,
            garden_bins => $garden_bins,
            garden_sacks => $garden_sacks,
            garden_container => $garden_container,
            garden_cost => $garden_cost,
            garden_due => $garden_due,
            garden_container_end_date => $garden_container_end_date,
            garden_overdue => $garden_overdue,
            request_allowed => $request_allowed,
            requests_open => $open_requests,
            request_containers => $containers,
            request_max => $request_max,
            service_task_id => $servicetask->{Id},
            service_task_name => $servicetask->{TaskTypeName},
            service_task_type_id => $servicetask->{TaskTypeId},
            # FD-3942 - comment this out so Frequency not shown in front end
            $self->moniker eq 'bromley' ? () : (schedule => $schedules->{description}),
            last => $schedules->{last},
            next => $schedules->{next},
            end_date => $schedules->{end_date},
            $self->moniker eq 'brent' ? (timeband => $_->{timeband}) : (),
        };
        if ($row->{last}) {
            my $ref = join(',', @{$row->{last}{ref}});
            $task_ref_to_row{$ref} = $row;

            $row->{report_allowed} = $self->within_working_days($row->{last}{date}, 2);

            if ($self->moniker eq 'sutton') {
                # Sutton needs to know about events from before the last collection in case there
                # have been missed container escalations that are still relevant
                $row->{all_events} = $events->filter({ service => $service_id });
            }

            my $events_unit = $self->_parse_events($calls->{"GetEventsForObject ServiceUnit $_->{Id}"});
            $row->{events} = $events->combine($events_unit)->filter({ service => $service_id, since => $row->{last}{date} });
            my $recent_events = $row->{events}->filter({ type => 'missed' });
            $row->{report_open} = ($recent_events->list)[0];
        }
        push @out, $row;
    }

    $self->waste_task_resolutions($calls->{GetTasks}, \%task_ref_to_row);
    $self->call_hook(munge_bin_services_for_address => \@out);

    return \@out;

}

sub waste_extra_service_info_all_results { }

sub waste_relevant_serviceunits {
    my ($self, $result) = @_;
    my @rows;
    foreach (@$result) {
        my $servicetask = $self->_get_current_service_task($_) or next;
        push @rows, {
            Id => $_->{Id},
            ServiceId => $_->{ServiceId},
            ServiceTask => $servicetask,
            Schedules => _parse_schedules($servicetask),
        };
    }
    return @rows;
}

=over

=item within_working_days

Given a DateTime object and a number, return true if today is less than or
equal to that number of working days (excluding weekends and bank holidays)
after the date. Sutton includes Bank Holidays as working days.

=cut

sub within_working_days {
    my ($self, $dt, $days, $future) = @_;
    my $holidays = $self->council_url eq 'sutton' ? [] : FixMyStreet::Cobrand::UK::public_holidays();
    my $wd = FixMyStreet::WorkingDays->new(public_holidays => $holidays);
    $dt = $wd->add_days($dt, $days)->ymd;
    my $today = DateTime->now->set_time_zone(FixMyStreet->local_time_zone)->ymd;
    if ( $future ) {
        return $today ge $dt;
    } else {
        return $today le $dt;
    }
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

sub _parse_events {
    my ($self, $events_data, $params) = @_;
    my $events = Integrations::Echo::Events->new({
        cobrand => $self,
        event_types => $self->missed_event_types,
        include_closed_requests => $params->{include_closed_requests},
    })->parse($events_data);
    return $events;
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

=head2 waste_on_the_day_criteria

Treat an Outstanding/Allocated task as if it's the next collection and in
progress, and do not allow missed collection reporting if the task is not
completed.

=cut

sub waste_on_the_day_criteria {
    my ($self, $completed, $state, $now, $row) = @_;

    if ($state eq 'Outstanding' || $state eq 'Allocated') {
        $row->{next} = $row->{last};
        $row->{next}{state} = 'In progress';
        delete $row->{last};
    }
    if (!$completed) {
        $row->{report_allowed} = 0;
    }
}

sub bin_future_collections {
    my $self = shift;

    my $services = $self->{c}->stash->{service_data};
    my %names;
    foreach (@$services) {
        next unless $_->{service_task_id};
        push @{$names{$_->{service_task_id}}}, $_->{service_name};
    }

    my $start = DateTime->now->set_time_zone(FixMyStreet->local_time_zone)->truncate( to => 'day' );
    my %timeframe = $self->bin_future_timeframe;
    my $end = $start->clone->add(%timeframe);

    my $echo = $self->feature('echo');
    $echo = Integrations::Echo->new(%$echo);
    my $result = $echo->GetServiceTaskInstances($start, $end, sort keys %names);

    my $events = [];
    foreach (@$result) {
        my $task_id = $_->{ServiceTaskRef}{Value}{anyType};
        my $tasks = Integrations::Echo::force_arrayref($_->{Instances}, 'ScheduledTaskInfo');
        foreach (@$tasks) {
            my $dt = construct_bin_date($_->{CurrentScheduledDate});
            my $summary = join('/', @{$names{$task_id}}) . ' collection';
            my $desc = '';
            push @$events, { date => $dt, summary => $summary, desc => $desc };
        }
    }
    return $events;
}

sub bin_future_timeframe { ( months => 3 ) }

sub split_echo_external_status_code { 1 }

=head2 admin_templates_external_status_code_hook

In order to provide more nuanced messaging on the bin day
page with regards to not complete collections, the external
status code admin is split into three fields, which are then
combined here for storage.

=cut

sub admin_templates_external_status_code_hook {
    my ($self) = @_;
    my $c = $self->{c};

    my $res_code = $c->get_param('resolution_code') || '';
    my $task_type = $c->get_param('task_type') || '';
    my $task_state = $c->get_param('task_state') || '';

    my $code = "$res_code,$task_type,$task_state";
    $code =~ s/,,$//;

    return $code;
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
        my @contacts = $body->contacts->search({
            extra => { '@>' => '{"type":"waste"}' }
        })->all;
        die "Could not find any waste contacts\n" unless @contacts;
        $report_params = { category => [ map { $_->category } @contacts ] };
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

    my $updates = Open311::GetServiceRequestUpdates->new(
        current_open311 => $open311,
        current_body => $body,
        system_user => $body->comment_user,
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
        %$report_params,
    });

    while (my $report = $reports->next) {
        print 'Fetching data for report ' . $report->id . "\n" if $cfg->{verbose};

        (my $external_id = $report->external_id) =~ s/^Echo-//;
        my $event = $cfg->{echo}->GetEvent($external_id);
        my $request = $self->construct_waste_open311_update($cfg, $event) or next;
        $request->{echo_event} = $event;

        next if !$request->{status} || $request->{status} eq 'confirmed'; # Still in initial state
        next unless $self->waste_check_last_update(
            'fetch', $cfg, $report, $request->{status}, $request->{external_status_code});

        my $last_updated = construct_bin_date($event->{LastUpdatedDate});
        $request->{comment_time} = $last_updated;

        print "  Updating report to state $request->{status}, $request->{description} ($request->{external_status_code})\n" if $cfg->{verbose};
        if ($cobrand->moniker eq 'brent') {
            # Suppress alerts for garden waste
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
    my $external_status_code = $resolution_id ? "$resolution_id" : "";
    my %extra = $self->call_hook(open311_waste_update_extra => $cfg, $event);
    return {
        description => $description,
        status => $status,
        update_id => 'waste',
        external_status_code => $external_status_code,
        prefer_template => 1,
        fms_extra_resolution_code => $event_type->{resolution}{$resolution_id} || '',
        fms_extra_event_status => $event_type->{states}{$state_id}{name} || '',
        %extra,
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
    my ($self, $type, $cfg, $report, $status, $resolution_id) = @_;

    my $latest = $report->comments->search(
        { external_id => 'waste', },
    )->order_by('-id')->first;

    if ($latest) {
        my $state = $cfg->{updates}->current_open311->map_state($status);
        my $code = $latest->get_extra_metadata('external_status_code') || '';
        my $problem_state = $latest->problem->state;
        if ($latest->problem_state eq $state && $code eq $resolution_id
            && !($type eq 'push' && $problem_state ne $state)) {
            print "  Latest update matches fetched state, skipping\n" if $cfg->{verbose};
            return;
        }
    }
    if ($report->cobrand eq 'merton' && $status eq 'cancelled'
        && $report->category eq 'Bulky collection' && $report->state eq 'cancelled') {
        print "  Cancelled update received on already cancelled report\n" if $cfg->{verbose};
        return;
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

=head2 waste_sub_due

Returns true/false if now is less than garden_due_days before DATE.

=cut

sub waste_sub_due {
    my ($self, $date) = @_;

    my $now = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);
    my $sub_end = DateTime::Format::W3CDTF->parse_datetime($date);

    my $diff = $now->delta_days($sub_end)->in_units('days');
    return $diff <= $self->garden_due_days;
}

=head2 waste_sub_overdue

Returns true/false if now is past DATE and (if provided)
less than COUNT INTERVAL after.

=cut

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

# Garden waste

sub waste_display_payment_method {
    my ($self, $method) = @_;

    my $display = {
        direct_debit => _('Direct Debit'),
        credit_card => _('Credit Card'),
    };

    return $display->{$method};
}

sub garden_current_subscription { $_[0]->{c}->stash->{services}{$_[0]->garden_service_id} }
sub get_current_garden_bins { shift->garden_current_subscription->{garden_bins} }

sub garden_current_service_from_service_units {
    my ($self, $services) = @_;

    my $garden;
    for my $service ( @$services ) {
        if ( $service->{ServiceId} == $self->garden_service_id ) {
            $garden = $self->_get_current_service_task($service);
            last;
        }
    }

    return $garden;
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
        $self->{c}->waste_cache_delete($key);
    }
}

sub clear_cached_lookups_bulky_slots {
    my ( $self, $id, $skip_echo ) = @_;

    for (qw/earlier later/) {
        $self->{c}->waste_cache_delete($self->council_url . ":echo:available_bulky_slots:$_:$id");
    }

    return if $skip_echo;

    # We also need to cancel the reserved slots in Echo
    my $guid_key = $self->council_url . ":echo:bulky_event_guid:$id";
    my $guid = $self->{c}->waste_cache_get($guid_key);

    return unless $guid;

    my $cfg = $self->feature('echo');
    my $echo = Integrations::Echo->new(%$cfg);
    $echo->CancelReservedSlotsForEvent($guid);
}

sub bulky_refetch_slots {
    my ($self, $row, $verbose) = @_;

    my $property_id = $row->waste_property_id;
    my $date = $self->collection_date($row);
    my $guid = $row->get_extra_field_value('GUID');
    my $window = $self->_bulky_collection_window();

    my $cfg = $self->feature('echo');
    my $echo = Integrations::Echo->new(%$cfg);

    my $service_id = $cfg->{bulky_service_id};
    my $event_type_id = $cfg->{bulky_event_type_id};

    if ($row->whensent || !$guid) {
        if ($row->whensent) {
            say "Already sent, creating new GUID and fetching new reservation and resending" if $verbose;
        } else {
            say "No GUID? Creating new GUID and fetching new reservation and sending" if $verbose;
        }
        require UUID::Tiny;
        $guid = UUID::Tiny::create_uuid_as_string();
        $row->update_extra_field({ name => 'GUID', value => $guid });
        $row->state('confirmed');
        $row->resend;
    } else {
        say "Not already sent, fetching new reservation and trying again" if $verbose;
        say "Cancelling existing slots for $guid" if $verbose;
        $echo->CancelReservedSlotsForEvent($guid);
    }

    say "Getting more slots for $property_id $guid" if $verbose;
    my $slots = $echo->ReserveAvailableSlotsForEvent($service_id, $event_type_id, $property_id, $guid, $window->{date_from}, $window->{date_to});

    my $slot_found = 0;
    foreach (@$slots) {
        my $slot_date = construct_bin_date($_->{StartDate});
        my $ref = $_->{Reference};
        if ($slot_date->ymd eq $date->ymd) {
            $slot_found = 1;
            say "Updating reservation to slot $ref for $slot_date" if $verbose;
            $row->update_extra_field({ name => 'reservation', value => $ref });
        }
    }
    if ($slot_found) {
        $row->send_fail_count(0); # Assuming it's been failing, for an instant retry
        $row->update;
    } else {
        say "No replacement slot for $date could be found" if $verbose;
    }
}

sub bulky_check_missed_collection {
    my ($self, $events, $blocked_codes) = @_;

    my $cfg = $self->feature('echo');
    my $service_id = $cfg->{bulky_service_id} or return;
    my $service_id_missed = $cfg->{bulky_service_id_missed};
    my $event_type_id = $cfg->{bulky_event_type_id} or return;
    my $bulky_events = $events->filter({ event_type => $event_type_id });
    return unless $bulky_events;
    my $missed_events = $events->filter({ type => 'missed', service => $service_id });

    foreach my $event ($bulky_events->list) {
        my $guid = $event->{guid};
        my $row = {
            service_name => 'Bulky waste',
            service_id => $service_id_missed || $service_id,
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

        # Open events are coming through and we only want to continue under specific circumstances with an open event
        next unless (!$event->{state} || $event->{state} ne 'open') || $self->{c}->cobrand->call_hook('bulky_open_overdue', $event);

        $row->{report_allowed} = $in_time && !$row->{report_locked_out};

        # Loop through the missed events and see if any of them is for this bulky event
        foreach ($missed_events->list) {
            next unless $_->{report};
            my $reported_guid = $_->{report}->get_extra_field_value('Original_Event_ID');
            next unless $reported_guid;
            $row->{report_open} = $_ if $reported_guid eq $guid;
        }

        $self->{c}->stash->{bulky_missed}{$guid} = $row;
    }
}

sub find_available_bulky_slots {
    my ( $self, $property, $last_earlier_date_str, $no_cache ) = @_;

    my $key
        = $self->council_url . ":echo:available_bulky_slots:"
        . ( $last_earlier_date_str ? 'later' : 'earlier' ) . ':'
        . $property->{id};
    if (!$no_cache) {
        my $data = $self->{c}->waste_cache_get($key);
        return $data if $data;
    }

    my $cfg = $self->feature('echo');
    my $echo = Integrations::Echo->new(%$cfg);

    my $service_id = $cfg->{bulky_service_id};
    my $event_type_id = $cfg->{bulky_event_type_id};

    my $guid_key = $self->council_url . ":echo:bulky_event_guid:" . $property->{id};
    my $guid = $self->{c}->waste_cache_get($guid_key);
    unless ($guid) {
        require UUID::Tiny;
        $guid = UUID::Tiny::create_uuid_as_string();
        $self->{c}->waste_cache_set($guid_key, $guid);
    }

    my $window = $self->_bulky_collection_window($last_earlier_date_str);
    my @available_slots;
    my $slots = $echo->ReserveAvailableSlotsForEvent($service_id, $event_type_id, $property->{id}, $guid, $window->{date_from}, $window->{date_to});
    $self->{c}->session->{first_date_returned} = undef;
    foreach (@$slots) {
        my $date = construct_bin_date($_->{StartDate})->datetime;
        push @available_slots, {
            date => $date,
            reference => $_->{Reference},
            expiry => construct_bin_date($_->{Expiry})->datetime,
        };
        $self->{c}->session->{first_date_returned} //= $date;
    }

    $self->{c}->waste_cache_set($key, \@available_slots) if !$no_cache;

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
        # Cancel the expired slots and call ReserveAvailableSlots again, try to
        # get the same collection date
        my $property = $self->{c}->stash->{property};
        $self->clear_cached_lookups_bulky_slots($property->{id});

        my $available_slots = $self->find_available_bulky_slots(
            $property, undef, 'no_cache' );

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
            my $display = $value;
            if (my $note = $report->get_extra_metadata("item_notes_$item")) {
                $display .= " ($note)";
            }
            push @fields, { item => $value, display => $display };
        }
    }
    my $items_extra = $self->bulky_items_extra(exclude_pricing => 1);

    return [
        map {
            value => $_->{display},
            message => $items_extra->{$_->{item}}{message},
        },
        @fields,
    ];
}

sub send_bulky_payment_echo_update_failed {
    my ( $self, $params ) = @_;

    my $email
        = ( $self->feature('waste_features') || {} )
        ->{echo_update_failure_email};
    return unless $email;

    # 3 hours to allow for Echo downtime
    my $dtf = FixMyStreet::DB->schema->storage->datetime_parser;
    my $cutoff_date
        = $dtf->format_datetime( DateTime->now->subtract( hours => 3 ) );

    my $rs = FixMyStreet::DB->resultset('Problem')->search(
        {   category => 'Bulky collection',
            cobrand  => $self->moniker,
            created  => { '<'  => $cutoff_date },
            extra    => { '\?' => 'payment_reference' },
            -not => {
                extra => {
                    '\?' => [
                        'echo_update_failure_email_sent',
                        'echo_update_sent',
                    ],
                },
            },
        },
    );

    while ( my $report = $rs->next ) {
        # Ignore if there is an update in Comment table with an external_id
        if ( $report->comments->search({
            external_id => { '!=', undef },
            text => { like => 'Payment confirmed%' },
            # Can be extra => { '\?' => 'fms_extra_payments' }, after that's added
        })->count) {
            # Set flag so we don't repeatedly check the comments for this
            # report
            $report->set_extra_metadata( echo_update_sent => 1 );
            $report->update;

            next;
        }

        # Send email
        my $h = {
            report  => $report,
            cobrand => $self,
        };

        my $result = eval {
            FixMyStreet::Email::send_cron(
                FixMyStreet::DB->schema,
                'waste/bulky_payment_echo_update_failed.txt',
                $h,
                { To => $email },
                undef,    # env_from
                $params->{nomail},
                $self,
                $report->lang,
            );
        };

        if ($@) {
            warn 'Sending for report ' . $report->id . " failed: $@\n";
        } elsif ($result) {
            print 'Sending for report ' . $report->id . ": failed\n"
                if $params->{verbose};
        } else {
            $report->set_extra_metadata(
                echo_update_failure_email_sent => 1 );
            $report->update;

            $report->comments->search({
                external_id => undef,
                text => { like => 'Payment confirmed%' },
                # Can be extra => { '\?' => 'fms_extra_payments' }, after that's added
            })->update({ send_state => 'skipped' });

            print 'Sending for report ' . $report->id . ": succeeded\n"
                if $params->{verbose};
        }
    }
}

sub per_photo_size_limit_for_report_in_bytes {
    my ($self, $report, $image_count) = @_;

    # We only need to check bulky collections at present.
    return 0 unless $report->cobrand_data eq 'waste' && $report->contact->category eq 'Bulky collection';

    my $cfg = FixMyStreet->config('COBRAND_FEATURES');
    return 0 unless $cfg;

    my $echo_cfg = $cfg->{'echo'};
    return 0 unless $echo_cfg;

    my $max_size_per_image = $echo_cfg->{'max_size_per_image_bytes'};
    my $max_size_images_total = $echo_cfg->{'max_size_image_total_bytes'};

    return 0 unless $max_size_per_image || $max_size_images_total;
    return $max_size_per_image if !$max_size_images_total;

    my $max_size_per_image_from_total = floor($max_size_images_total / $image_count);
    return $max_size_per_image_from_total if !$max_size_per_image;

    return min($max_size_per_image, $max_size_per_image_from_total);
};

sub _bulky_date_to_dt {
    my ($self, $date) = @_;
    $date = (split(";", $date))[0];
    my $parser = DateTime::Format::Strptime->new( pattern => '%FT%T', time_zone => FixMyStreet->local_time_zone);
    my $dt = $parser->parse_datetime($date);
    return $dt ? $dt->truncate( to => 'day' ) : undef;
}

1;
