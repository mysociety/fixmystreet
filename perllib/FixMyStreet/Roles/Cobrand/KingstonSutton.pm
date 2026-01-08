=head1 NAME

FixMyStreet::Roles::Cobrand::KingstonSutton - shared code for Kingston and Sutton WasteWorks

=head1 DESCRIPTION

=cut

package FixMyStreet::Roles::Cobrand::KingstonSutton;

use Moo::Role;
use Hash::Util qw(lock_hash);
use List::Util qw(max);

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

=item * We can send multiple photos through to Echo, directly

=back

=cut

sub open311_config {
    my ($self, $row, $h, $params, $contact) = @_;
    $params->{multi_photos} = 1;
    $params->{upload_files} = 1;
}

=head2 state_groups_admin / available_permissions

We do not need all the states and permissions for only WasteWorks.

=cut

sub state_groups_admin {
    [
        [ New => [ 'confirmed' ] ],
        [ Pending => [ 'investigating', 'action scheduled' ] ],
        [ Closed => [ 'fixed - council', 'unable to fix', 'closed', 'duplicate', 'cancelled' ] ],
        [ Hidden => [ 'unconfirmed', 'hidden', 'partial' ] ],
    ]
}

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
        Waste => {
            wasteworks_config => "Can edit WasteWorks configuration",
        },
    };
}

sub waste_auto_confirm_report { 1 }

=head2 Garden

=over 4

=item * Garden subscriptions can be renewed 30 days before they end.

=cut

sub garden_due_date {
    my ($self, $end_date) = @_;
    return $end_date->subtract(days => 30);
};

=item * Even staff must provide an email address for garden subscriptions

=cut

sub garden_staff_provide_email { 1 }

=item * Do not offer people to set a password

=cut

sub waste_password_hidden { 1 }

=item * Allow people to edit the current number of bins for renewal/modify

=back

=cut

sub waste_allow_current_bins_edit { 1 }

=head2 waste_munge_report_form_fields

We use a custom report form to add some text to the "About you" page.

=cut

sub waste_munge_report_form_fields {
    my ($self, $field_list) = @_;
    $self->{c}->stash->{form_class} = 'FixMyStreet::App::Form::Waste::Report::SLWP';
}

=head2 waste_report_form_first_next

After picking a service, we jump straight to the about you page unless it's
bulky or small items, where we ask for more information.

=cut

sub waste_report_form_first_next {
    my $self = shift;
    my $cfg = $self->feature('echo');
    my $bulky_service_id       = $cfg->{bulky_service_id};
    my $small_items_service_id = $cfg->{small_items_service_id};
    return sub {
        my $data = shift;
        return 'notes'
            if ( $bulky_service_id && $data->{"service-$bulky_service_id"} )
            || ( $small_items_service_id && $data->{"service-$small_items_service_id"} );
        return 'about_you';
    };
}

=head2 Escalations

Kingston and Sutton have custom behaviour to allow escalation of unresolved missed collections
or container requests.

=cut

around booked_check_missed_collection => sub {
    my ($orig, $self, $type, $events, $blocked_codes) = @_;

    $self->$orig($type, $events, $blocked_codes);

    # Now check for any old open missed collections that can be escalated

    my $cfg = $self->feature('echo');
    my $service_id = $cfg->{$type . '_service_id'} or return;

    my $escalations = $events->filter({ event_type => 3134, service => $service_id });
    my $missed = $self->{c}->stash->{booked_missed};
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

        my $wd = FixMyStreet::WorkingDays->new();
        if ($self->waste_target_days->{missed_bulky}) {
            $self->{c}->stash->{booked_missed}->{target} = $wd->add_days($missed_event->{date}, $self->waste_target_days->{missed_bulky})->set_hour($self->waste_day_end_hour);
        }

        if (
            # Report is still open
            !$missed_event->{closed}
            # And no existing escalation since last collection
            && !$open_escalation
        ) {
            my $now = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);
            # And two working days (from 6pm) have passed
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

    my $wd = FixMyStreet::WorkingDays->new();
    if ($row->{report_open} && $self->waste_target_days && $self->waste_target_days->{missed}) {
        $row->{report_open}->{target} = $wd->add_days($row->{report_open}->{date}, $self->waste_target_days->{missed})->set_hour($self->waste_day_end_hour);
    }

    my $missed_event = ($events->filter({ type => 'missed' })->list)[0];
    my $escalation_event = ($events->filter({ event_type => 3134 })->list)[0];
    if (
        # If there's a missed bin report
        $missed_event
        # And report is still open
        && !$missed_event->{closed}
        # And the event source is the same as the current property (for communal)
        && ($missed_event->{source} || 0) == $property->{id}
        # And no existing escalation since last collection
        && !$escalation_event
    ) {
        my $day_cfg = $self->waste_escalation_window;
        my $now = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);

        my $start = $wd->add_days($missed_event->{date}, $day_cfg->{missed_start})->set_hour($self->waste_day_end_hour);
        # And window is one day (weekly) two WDs (fortnightly)
        my $window = $row->{schedule} =~ /every other/i ? $day_cfg->{missed_length_fortnightly} : $day_cfg->{missed_length_weekly};
        my $end = $wd->add_days($start, $window);
        if ($now >= $start && $now < $end) {
            $row->{escalations}{missed} = $missed_event;
        }
    } elsif ($escalation_event) {
        if ($self->waste_target_days && $self->waste_target_days->{missed_escalation}) {
            $escalation_event->{target} = $wd->add_days($escalation_event->{date}, $self->waste_target_days->{missed_escalation})->set_hour($self->waste_day_end_hour);
        }
        $row->{escalations}{missed_open} = $escalation_event;
    }
}

sub waste_target_days { {} }

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
            if ($self->waste_target_days && $self->waste_target_days->{container_escalation}) {
                $escalation_event->{target} = $wd->add_days($escalation_event->{date}, $self->waste_target_days->{container_escalation});
            }
            $row->{escalations}{container_open} = $escalation_event;
            # We've marked that there is already an escalation event for the container
            # request, so there's nothing left to do
            return;
        }
    }

    # There's an open container request with no matching escalation so
    # we check now to see if it's within the window for an escalation to be raised
    my $now = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);

    my $day_cfg = $self->waste_escalation_window;
    my $start_days = $day_cfg->{container_start};
    my $window_days = $day_cfg->{container_length};
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

=head2 waste_cc_payment_line_item_ref

This is used by the SCP role (all Kingston, Sutton requests) to provide the
reference for the credit card payment. It differs for bulky waste.

=cut

sub waste_cc_payment_line_item_ref {
    my ($self, $p) = @_;
    if ($p->category eq 'Bulky collection') {
        my $type = $self->moniker eq 'sutton' ? 'BWB' : 'BULKY';
        return $self->_waste_cc_line_item_ref($p, $type, "");
    } elsif ($p->category eq 'Request new container') {
        return $self->_waste_cc_line_item_ref($p, "CCH", "");
    } else {
        return $self->_waste_cc_line_item_ref($p, "GGW", "GW Sub");
    }
}

sub waste_cc_payment_admin_fee_line_item_ref {
    my ($self, $p) = @_;
    return $self->_waste_cc_line_item_ref($p, "GGW", "GW admin charge");
}

sub _waste_cc_line_item_ref {
    my ($self, $p, $type, $str) = @_;
    my $id = $self->waste_payment_ref_council_code . "-$type-" . $p->id;
    my $len = 50 - length($id) - 1;
    if ($str) {
        $str = "-$str";
        $len -= length($str);
    }
    my $name = substr($p->name, 0, $len);
    return "$id-$name$str";
}

sub waste_cc_payment_sale_ref {
    my ($self, $p) = @_;
    return "GGW" . $p->uprn;
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

    my $config = $self->wasteworks_config || {};
    my $max_items = max(
        $config->{small_items_per_collection_max} || 0,
        $config->{items_per_collection_max} || 0,
        5
    );

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
        # Escalations
        $self->moniker eq 'sutton' ? (original_ref => 'Original reference') : (),
        map { "item_" . $_ => "Item $_" } (1..$max_items),
    );

    $csv->objects_attrs({
        '+columns' => ['user.email', 'user.phone'],
        join => 'user',
    });

    $csv->csv_extra_data(sub {
        my $report = shift;

        my %fields;
        if ($csv->dbi) {
            %fields = %{$report->{extra}{_field_value} || {}};
        } else {
            my @fields = @{ $report->get_extra_fields() };
            %fields = map { $_->{name} => $_->{value} } @fields;
        }

        my $detail = $csv->dbi ? $report->{detail} : $report->detail;
        $detail =~ s/^.*?\n\n//; # Remove waste category

        my $data = {
            detail => $detail,
            $csv->dbi ? (
                user_name_display => $report->{name},
                payment_reference => $report->{extra}{payment_reference} || '',
            ) : (
                uprn => $report->uprn,
                user_name_display => $report->name,
                user_email => $report->user->email || '',
                user_phone => $report->user->phone || '',
                payment_reference => $report->get_extra_metadata('payment_reference') || '',
            ),
            payment_method => $fields{payment_method} || '',
            payment => $fields{payment},
            pro_rata => $fields{pro_rata},
            admin_fee => $fields{admin_fee},
            container => $fields{Paid_Container_Type} || $fields{Subscription_Details_Containers},
            current_bins => $fields{current_containers},
            quantity => $fields{Paid_Container_Quantity} || $fields{Subscription_Details_Quantity},
            original_ref => $fields{original_ref},
        };

        my $extra = $csv->_extra_metadata($report);
        %$data = (%$data, map {$_ => $extra->{$_} || ''} grep { $_ =~ /^(item_\d+)$/ } keys %$extra);

        return $data;
    });
}

1;
