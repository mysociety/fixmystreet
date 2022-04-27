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

sub council_area_id { return 2480; }
sub council_area { return 'Kingston'; }
sub council_name { return 'Kingston upon Thames Council'; }
sub council_url { return 'kingston'; }

sub admin_user_domain { ('kingston.gov.uk', 'sutton.gov.uk') }

sub send_questionnaires { 0 }

sub abuse_reports_only { 1 }

sub waste_check_staff_payment_permissions {
    my $self = shift;
    my $c = $self->{c};

    return unless $c->stash->{is_staff};

    $c->stash->{staff_payments_allowed} = 1;
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

# We want to send confirmation emails only for Waste reports
sub report_sent_confirmation_email {
    my ($self, $report) = @_;
    my $contact = $report->contact or return;
    return 'id' if grep { $_ eq 'Waste' } @{$contact->groups};
    return '';
}

sub munge_around_category_where {
    my ($self, $where) = @_;
    $where->{extra} = [ undef, { -not_like => '%Waste%' } ];
}

sub munge_reports_category_list {
    my ($self, $categories) = @_;
    my $c = $self->{c};
    return if $c->action eq 'dashboard/heatmap';

    unless ( $c->user_exists && $c->user->from_body && $c->user->has_permission_to('report_mark_private', $self->body->id) ) {
        @$categories = grep { grep { $_ ne 'Waste' } @{$_->groups} } @$categories;
    }
}

sub munge_report_new_contacts {
    my ($self, $categories) = @_;

    if ($self->{c}->action =~ /^waste/) {
        @$categories = grep { grep { $_ eq 'Waste' } @{$_->groups} } @$categories;
        return;
    }

    if ($self->{c}->stash->{categories_for_point}) {
        # Have come from an admin tool
    } else {
        @$categories = grep { grep { $_ ne 'Waste' } @{$_->groups} } @$categories;
    }
    $self->SUPER::munge_report_new_contacts($categories);
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

sub image_for_service {
    my ($self, $service_id) = @_;
    my $base = '/cobrands/kingston/container-images';
    my $images = {
        1906 => "$base/black-bin-blue-lid", # paper and card
        1903 => "$base/black-bin", # refuse
        1908 => "$base/brown-bin", # food
        1909 => "$base/green-bin", # dry mixed
        1914 => "$base/garden-waste-bin",
        1915 => "$base/garden-waste-bag",
    };
    return $images->{$service_id};
}

sub garden_waste_service_id {
    return 1914; # XXX And 1915
}

sub get_current_garden_bins {
    my ($self) = @_;

    my $service = $self->garden_waste_service_id;
    my $bin_count = $self->{c}->stash->{services}{$service}->{garden_bins};

    return $bin_count;
}

sub service_name_override {
    my ($self, $service) = @_;

    my %service_name_override = (
        1906 => 'Paper and card',
        1903 => 'Refuse',
        1908 => 'Food',
        1909 => 'Mixed',
        1914 => 'Garden Waste',
        1915 => 'Garden Waste bag',
    );

    return $service_name_override{$service} || 'Unknown';
}

sub bin_payment_types {
    return {
        'csc' => 1,
        'credit_card' => 2,
        'direct_debit' => 3,
    };
}

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

sub bin_services_for_address {
    my $self = shift;
    my $property = shift;

    $self->{c}->stash->{containers} = {
        26 => 'Garden Waste Bin',
        28 => 'Garden Waste Sacks',
    };

    $self->{c}->stash->{container_actions} = $self->waste_container_actions;

    my %service_to_containers = (
        1914 => [ 26 ],
        1915 => [ 28 ],
    );
    my %request_allowed = map { $_ => 1 } keys %service_to_containers;
    my %quantity_max = (
        1914 => 5,
    );

    $self->{c}->stash->{quantity_max} = \%quantity_max;

    $self->{c}->stash->{garden_subs} = $self->waste_subscription_types;

    my $result = $self->{api_serviceunits};
    return [] unless @$result;

    my $events = $self->_parse_events($self->{api_events});
    $self->{c}->stash->{open_service_requests} = $events->{enquiry};

    # If there is an open Garden subscription (2106) event, assume
    # that means a bin is being delivered and so a pending subscription
    $self->{c}->stash->{pending_subscription} = $events->{enquiry}{2106} ? { title => 'Garden Subscription' } : undef;

    my @to_fetch;
    my %schedules;
    my @task_refs;
    my %expired;
    foreach (@$result) {
        my $servicetasks = $self->_get_service_tasks($_);
        foreach my $task (@$servicetasks) {
            my $service_id = $task->{TaskTypeId};

            # Only Garden for now XXX
            next unless $service_id == 1914 || $service_id == 1915;
            # Only Garden for now XXX

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
            my $garden_cost = 0;
            my $garden_due = $self->waste_sub_due($schedules->{end_date});
            my $garden_overdue = $expired{$service_id};
            if ($service_name eq 'Garden Waste') {
                $garden = 1;
                my $data = Integrations::Echo::force_arrayref($task->{Data}, 'ExtensibleDatum');
                foreach (@$data) {
                    next unless $_->{DatatypeName} eq 'SLWP - Containers'; # DatatypeId 3346
                    my $moredata = Integrations::Echo::force_arrayref($_->{ChildData}, 'ExtensibleDatum');
                    foreach (@$moredata) {
                        # $container = $_->{Value} if $_->{DatatypeName} eq 'Container Type'; # should be 26 or 28
                        if ( $_->{DatatypeName} eq 'Quantity' ) {
                            $garden_bins = $_->{Value};
                            $garden_cost = $self->garden_waste_cost_pa($garden_bins) / 100;
                        }
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

    # TODO This will need to sometimes be a sack!
    my $container = $container_types{'Garden Waste Bin'};

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

1;
