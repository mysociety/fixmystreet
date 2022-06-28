package FixMyStreet::Cobrand::Kingston;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;
use utf8;
use DateTime::Format::W3CDTF;
use Integrations::Echo;
use FixMyStreet::WorkingDays;
use JSON::MaybeXS;
use LWP::Simple;
use Moo;
with 'FixMyStreet::Roles::CobrandEcho';
with 'FixMyStreet::Roles::Bottomline';

sub council_area_id { return 2480; }
sub council_area { return 'Kingston'; }
sub council_name { return 'Kingston upon Thames Council'; }
sub council_url { return 'kingston'; }

sub admin_user_domain { ('kingston.gov.uk', 'sutton.gov.uk') }

sub send_questionnaires { 0 }

sub abuse_reports_only { 1 }

sub problems_restriction {
    my ($self, $rs) = @_;
    return $rs if FixMyStreet->staging_flag('skip_checks');
    $rs = $self->next::method($rs);
    my $table = ref $rs eq 'FixMyStreet::DB::ResultSet::Nearby' ? 'problem' : 'me';
    $rs = $rs->search({
        "$table.cobrand_data" => 'waste',
    });
    return $rs;
}

sub waste_check_staff_payment_permissions {
    my $self = shift;
    my $c = $self->{c};

    return unless $c->stash->{is_staff};

    $c->stash->{staff_payments_allowed} = 'cnp';
}

sub open311_extra_data_include {
    my ($self, $row, $h) = @_;

    my $open311_only = [
        #{ name => 'email', value => $row->user->email }
    ];

    if ( $row->category eq 'Garden Subscription' ) {
        if ( $row->get_extra_metadata('contributed_as') && $row->get_extra_metadata('contributed_as') eq 'anonymous_user' ) {
            push @$open311_only, { name => 'contributed_as', value => 'anonymous_user' };
        }
    }

    return $open311_only;
}

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
}

sub updates_disallowed {
    my $self = shift;
    my ($problem) = @_;

    # No updates on waste reports
    return 'waste' if $problem->cobrand_data eq 'waste';

    return $self->next::method(@_);
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
            emergency_message_edit => _("Add/edit emergency message"),
        },
    };
}

sub clear_cached_lookups_property {
    my ($self, $id) = @_;

    my $key = "kingston:echo:look_up_property:$id";
    delete $self->{c}->session->{$key};
    $key = "kingston:echo:bin_services_for_address:$id";
    delete $self->{c}->session->{$key};
}

around look_up_property => sub {
    my ($orig, $self, $id) = @_;
    my $data = $orig->($self, $id);
    my $cfg = $self->feature('echo');
    if ($cfg->{nlpg} && $data->{uprn}) {
        my $uprn_data = get(sprintf($cfg->{nlpg}, $data->{uprn}));
        $uprn_data = JSON::MaybeXS->new->decode($uprn_data);
        if ($uprn_data->{results}[0]{DPA}{LOCAL_CUSTODIAN_CODE_DESCRIPTION} ne 'KINGSTON UPON THAMES') {
            $self->{c}->stash->{template} = 'waste/missing.html';
            $self->{c}->detach;
        }
    }
    return $data;
};

sub image_for_unit {
    my ($self, $unit) = @_;
    my $base = '/cobrands/kingston/container-images';
    if (my $container = $unit->{garden_container}) {
        return "$base/garden-waste-bin" if $container == 26;
        return "";
    }
    my $service_id = $unit->{service_id};
    my $images = {
        1906 => "$base/black-bin-blue-lid", # paper and card
        1903 => "$base/black-bin", # refuse
        1908 => "$base/brown-bin", # food
        1909 => "$base/green-bin", # dry mixed
    };
    return $images->{$service_id};
}

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

use constant GARDEN_WASTE_SERVICE_ID => 2247;
sub garden_service_name { 'garden waste collection service' }
sub garden_service_id { GARDEN_WASTE_SERVICE_ID }
sub garden_current_subscription { shift->{c}->stash->{services}{+GARDEN_WASTE_SERVICE_ID} }
sub get_current_garden_bins { shift->garden_current_subscription->{garden_bins} }

sub garden_subscription_type_field { 'Request_Type' }
sub garden_subscription_container_field { 'Subscription_Details_Containers' }
sub garden_echo_container_name { 'SLWP - Containers' }

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
        1906 => 'Paper and card',
        1903 => 'Refuse',
        1908 => 'Food',
        1909 => 'Mixed',
        2247 => 'Garden Waste',
    );

    return $service_name_override{$service} || 'Unknown';
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

    $self->{c}->stash->{containers} = {
        26 => 'Garden Waste Bin',
        28 => 'Garden Waste Sacks',
    };

    $self->{c}->stash->{container_actions} = $self->waste_container_actions;

    my %service_to_containers = (
        #    1914 => [ 26 ],
        #    1915 => [ 28 ],
    );
    my %request_allowed = map { $_ => 1 } keys %service_to_containers;
    my %quantity_max = (
        2247 => 5,
    );

    $self->{c}->stash->{quantity_max} = \%quantity_max;

    $self->{c}->stash->{garden_subs} = $self->waste_subscription_types;

    my $result = $self->{api_serviceunits};
    unless (@$result && grep { $_->{ServiceId} == 409 } @$result) {
        # No garden collection possible
        $self->{c}->stash->{waste_features}->{garden_disabled} = 1;
        return [];
    }

    my $events = $self->_parse_events($self->{api_events});
    $self->{c}->stash->{open_service_requests} = $events->{enquiry};

    # If there is an open Garden subscription (2106) event, assume
    # that means a bin is being delivered and so a pending subscription
    $self->{c}->stash->{pending_subscription} = $events->{enquiry}{2106} ? { title => 'Garden Subscription' } : undef;

    # Refuse currently in separate Echo
    # This can be done within the loop below once this is not the case
    my $refuse = $self->property_has_domestic_refuse($property->{id});
    if ($refuse) {
        $self->{c}->stash->{garden_sacks} = $refuse eq 'sack';
    }

    my @to_fetch;
    my %schedules;
    my @task_refs;
    my %expired;
    foreach (@$result) {
        my $servicetasks = $self->_get_service_tasks($_);
        foreach my $task (@$servicetasks) {
            my $service_id = $task->{TaskTypeId};

            # Only Garden for now XXX
            next unless $service_id == $self->garden_service_id;
            # Only Garden for now XXX

            # When this covers more than garden, this code can replace the property_has_domestic_refuse above
            # XXX Might also need to check for 2238 (domestic refuse) to see if garden allowed at all
            #if ($service_id == 2242) { # Collect Domestic Refuse Bag
            #    $self->{c}->stash->{garden_sacks} = 1;
            #}

            my $schedules = _parse_schedules($task);
            $expired{$service_id} = $schedules if $self->waste_sub_overdue( $schedules->{end_date}, weeks => 4 );

            next unless $schedules->{next} or $schedules->{last};
            $schedules{$service_id} = $schedules;
            push @to_fetch, GetEventsForObject => [ ServiceUnit => $_->{Id} ];
            push @task_refs, $schedules->{last}{ref} if $schedules->{last};
        }
    }
    push @to_fetch, GetTasks => \@task_refs if @task_refs;

    my $cfg = $self->feature('echo');
    my $echo = Integrations::Echo->new(%$cfg);
    my $calls = $echo->call_api($self->{c}, 'kingston', 'bin_services_for_address:' . $property->{id}, @to_fetch);

    my @out;
    my %task_ref_to_row;
    foreach (@$result) {
        my $servicetasks = $self->_get_service_tasks($_);
        foreach my $task (@$servicetasks) {
            my $service_id = $task->{TaskTypeId};
            my $service_name = $self->service_name_override($service_id);
            next unless $schedules{$service_id} || ( $service_name eq 'Garden Waste' && $expired{$service_id} );

            my $schedules = $schedules{$service_id} || $expired{$service_id};

            my $containers = $service_to_containers{$service_id};
            my ($open_request) = grep { $_ } map { $events->{request}->{$_} } @$containers;

            my $request_max = $quantity_max{$service_id};

            my $garden = 0;
            my $garden_bins;
            my $garden_container;
            my $garden_cost = 0;
            my $garden_due = $self->waste_sub_due($schedules->{end_date});
            my $garden_overdue = $expired{$service_id};
            if ($service_name eq 'Garden Waste') {
                $garden = 1;
                my $data = Integrations::Echo::force_arrayref($task->{Data}, 'ExtensibleDatum');
                foreach (@$data) {
                    next unless $_->{DatatypeName} eq $self->garden_echo_container_name; # DatatypeId 3346
                    my $moredata = Integrations::Echo::force_arrayref($_->{ChildData}, 'ExtensibleDatum');
                    foreach (@$moredata) {
                        if ( $_->{DatatypeName} eq 'Container Type' ) { # should be 26 or 28
                            $garden_container = $_->{Value};
                        }
                        if ( $_->{DatatypeName} eq 'Quantity' ) {
                            $garden_bins = $_->{Value};
                        }
                    }
                    if ($garden_container == 28) {
                        $garden_cost = $self->garden_waste_sacks_cost_pa() / 100;
                    } else {
                        $garden_cost = $self->garden_waste_cost_pa($garden_bins) / 100;
                    }

                }
                $request_max = $garden_bins;

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
                request_allowed => $request_allowed{$service_id} && $request_max && $schedules->{next},
                request_open => $open_request,
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
    if (%task_ref_to_row) {
        my $tasks = $calls->{GetTasks};
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
                })->first;
                $resolution = $template->text if $template;
            }

            my $row = $task_ref_to_row{$ref};
            $row->{last}{state} = $state unless $state eq 'Completed' || $state eq 'Not Completed' || $state eq 'Outstanding' || $state eq 'Allocated';
            $row->{last}{completed} = $completed;
            $row->{last}{resolution} = $resolution;

            # Special handling if last instance is today
            if ($row->{last}{date}->ymd eq $now->ymd) {
                # If it's before 5pm and outstanding, show it as in progress
                if ($state eq 'Outstanding' && $now->hour < 17) {
                    $row->{next} = $row->{last};
                    $row->{next}{state} = 'In progress';
                    delete $row->{last};
                }
                if (!$completed && $now->hour < 17) {
                    $row->{report_allowed} = 0;
                }
            }

            # If the task is ended and could not be done, do not allow reporting
            if ($state eq 'Not Completed' || ($state eq 'Completed' && $orig_resolution eq 'Excess Waste')) {
                $row->{report_allowed} = 0;
                $row->{report_locked_out} = 1;
            }
        }
    }

    return \@out;
}

# Refuse currently in separate Echo - when not, could do this in main loop
sub property_has_domestic_refuse {
    my ($self, $id) = @_;
    my $cfg = $self->feature('echo_rbk');
    my $echo = Integrations::Echo->new(%$cfg);
    my $calls = $echo->call_api($self->{c}, $self->moniker,
        "look_up_property_rbk:$id",
        GetServiceUnitsForObject => [ $id ],
    );
    my $result = $calls->{"GetServiceUnitsForObject $id"};
    foreach (@$result) {
        next unless $_->{ServiceId} == 355;
        my $servicetasks = $self->_get_service_tasks($_);
        foreach (@$servicetasks) {
            my $id = $_->{TaskTypeId};
            return 'sack' if $id == 1904; # Collect Refuse Bag
            return 'bin' if $id == 1903; # Collect Refuse Bin
        }
    }
    return '';
}

#sub _closed_event {
#    my $event = shift;
#    return 1 if $event->{ResolvedDate};
#    return 1 if $event->{ResolutionCodeId} && $event->{ResolutionCodeId} != 584; # Out of Stock
#    return 0;
#}

sub _parse_events {
    my $self = shift;
    my $events_data = shift;
    my $events;
    foreach (@$events_data) {
#        my $event_type = $_->{EventTypeId};
#        my $type = 'enquiry';
#        $type = 'request' if $event_type == 2104;
#        $type = 'missed' if 2095 <= $event_type && $event_type <= 2103;
#
#        # Only care about open requests/enquiries
#        my $closed = _closed_event($_);
#        next if $type ne 'missed' && $closed;
#
#        if ($type eq 'request') {
#            my $data = $_->{Data} ? $_->{Data}{ExtensibleDatum} : [];
#            my $container;
#            DATA: foreach (@$data) {
#                if ($_->{ChildData}) {
#                    foreach (@{$_->{ChildData}{ExtensibleDatum}}) {
#                        if ($_->{DatatypeName} eq 'Container Type') {
#                            $container = $_->{Value};
#                            last DATA;
#                        }
#                    }
#                }
#            }
#            my $report = $self->problems->search({ external_id => $_->{Guid} })->first;
#            $events->{request}->{$container} = $report ? { report => $report } : 1;
#        } elsif ($type eq 'missed') {
#            my $report = $self->problems->search({ external_id => $_->{Guid} })->first;
#            my $service_id = $_->{ServiceId};
#            my $data = {
#                closed => $closed,
#                date => construct_bin_date($_->{EventDate}),
#            };
#            $data->{report} = $report if $report;
#            push @{$events->{missed}->{$service_id}}, $data;
#        } else { # General enquiry of some sort
#            $events->{enquiry}->{$event_type} = 1;
#        }
    }
    return $events;
}

sub bin_day_format { '%A, %-d~~~ %B' }

=over

=item within_working_days

Given a DateTime object and a number, return true if today is less than or
equal to that number of working days (excluding weekends and bank holidays)
after the date.

=cut

sub within_working_days {
    my ($self, $dt, $days, $future) = @_;
    my $wd = FixMyStreet::WorkingDays->new(public_holidays => FixMyStreet::Cobrand::UK::public_holidays());
    $dt = $wd->add_days($dt, $days)->ymd;
    my $today = DateTime->now->set_time_zone(FixMyStreet->local_time_zone)->ymd;
    if ( $future ) {
        return $today ge $dt;
    } else {
        return $today le $dt;
    }
}

sub waste_garden_sub_params {
    my ($self, $data, $type) = @_;
    my $c = $self->{c};

    my %container_types = map { $c->{stash}->{containers}->{$_} => $_ } keys %{ $c->stash->{containers} };

    my $container = $data->{garden_sacks} ? 'Garden Waste Sacks' : 'Garden Waste Bin';
    $container = $container_types{$container};

    $c->set_param('Request_Type', $type);
    $c->set_param('Subscription_Details_Containers', $container);
    $c->set_param('Subscription_Details_Quantity', $data->{bin_count});
    if ( $data->{new_bins} ) {
        my $action = ($data->{new_bins} > 0) ? 'deliver' : 'remove';
        $c->set_param('Bin_Delivery_Detail_Containers', $c->stash->{container_actions}->{$action});
        $c->set_param('Bin_Delivery_Detail_Container', $container);
        $c->set_param('Bin_Delivery_Detail_Quantity', abs($data->{new_bins}));
    }

    if ( $c->stash->{orig_sub} and ($c->stash->{orig_sub}->get_extra_field_value('payment_method')||'') eq 'direct_debit' ) {
        $c->set_param('dd_contact_id', $c->stash->{orig_sub}->get_extra_metadata('dd_contact_id'));
        $c->set_param('dd_mandate_id', $c->stash->{orig_sub}->get_extra_metadata('dd_mandate_id'));
    }

    # 2022 renewals need to end in March 2023
    my $now = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);
    if ($type && $type == $c->stash->{garden_subs}->{Renew} && $now->ymd("") < '20220801') {
        $c->set_param('End_Date', '31/03/2023');
    }
}

#sub waste_munge_request_data {
#    my ($self, $id, $data) = @_;
#
#    my $c = $self->{c};
#
#    my $address = $c->stash->{property}->{address};
#    my $container = $c->stash->{containers}{$id};
#    my $quantity = $data->{"quantity-$id"};
#    my $reason = $data->{replacement_reason} || '';
#    $data->{title} = "Request new $container";
#    $data->{detail} = "Quantity: $quantity\n\n$address";
#    $c->set_param('Container_Type', $id);
#    $c->set_param('Quantity', $quantity);
#    if ($id == 44) {
#        if ($reason eq 'damaged') {
#            $c->set_param('Action', '2::1'); # Remove/Deliver
#            $c->set_param('Reason', 3); # Damaged
#        } elsif ($reason eq 'stolen' || $reason eq 'taken') {
#            $c->set_param('Reason', 1); # Missing / Stolen
#        }
#    } else {
#        # Don't want to be remembered from previous loop
#        $c->set_param('Action', '');
#        $c->set_param('Reason', '');
#    }
#}

#sub waste_munge_report_data {
#    my ($self, $id, $data) = @_;
#
#    my $c = $self->{c};
#
#    my $address = $c->stash->{property}->{address};
#    my $service = $c->stash->{services}{$id}{service_name};
#   $data->{title} = "Report missed $service";
#    $data->{detail} = "$data->{title}\n\n$address";
#   $c->set_param('service_id', $id);
#}

#sub waste_munge_enquiry_data {
#    my ($self, $data) = @_;
#
#    my $address = $self->{c}->stash->{property}->{address};
#    $data->{title} = $data->{category};
#
#    my $detail;
#    foreach (grep { /^extra_/ } keys %$data) {
#        $detail .= "$data->{$_}\n\n";
#    }
#    $detail .= $address;
#    $data->{detail} = $detail;
#}

# Same as full cost
sub waste_get_pro_rata_cost {
    my ($self, $bins, $end) = @_;
    my $cost = $bins * $self->feature('payment_gateway')->{ggw_cost};
    return $cost;
}

sub waste_display_payment_method {
    my ($self, $method) = @_;

    my $display = {
        direct_debit => _('Direct Debit'),
        credit_card => _('Credit Card'),
    };

    return $display->{$method};
}

sub garden_waste_sacks_cost_pa {
    my ($self) = @_;
    my $cost = $self->feature('payment_gateway')->{ggw_sacks_cost};
    return $cost;
}

sub garden_waste_cost_pa {
    my ($self, $bin_count) = @_;

    $bin_count ||= 1;

    my $per_bin_cost = $self->feature('payment_gateway')->{ggw_cost};
    my $cost = $per_bin_cost * $bin_count;
    return $cost;
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

sub waste_cc_payment_line_item_ref {
    my ($self, $p) = @_;
    return _waste_cc_line_item_ref($p, "GW Sub");
}

sub waste_cc_payment_admin_fee_line_item_ref {
    my ($self, $p) = @_;
    return _waste_cc_line_item_ref($p, "GW admin charge");
}

sub _waste_cc_line_item_ref {
    my ($p, $str) = @_;
    my $id = 'RBK-GGW-' . $p->id;
    my $len = 50 - length($id) - length($str) - 2;
    my $name = substr($p->name, 0, $len);
    return "$id-$name-$str";
}

sub waste_payment_ref_council_code { "RBK" }

sub garden_waste_dd_redirect_url {
    my ($self, $p) = @_;

    my $c = $self->{c};

    return $c->cobrand->base_url_with_lang . "/waste/dd_complete";
}

sub garden_waste_dd_check_success {
    my ($self, $c) = @_;

    # check if the bank details have been verified
    my $applied = lc $c->get_param('verificationapplied') || '';
    if ( $applied eq 'true' ) {
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

sub waste_dd_payment_ref {
    my ($self, $p) = @_;

    return substr($self->waste_payment_ref_council_code . '-' . $p->id . '-' . $p->get_extra_field_value('uprn'), 0, 18);
}

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

1;
