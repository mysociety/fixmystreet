package FixMyStreet::Cobrand::Bromley;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;
use utf8;
use DateTime::Format::W3CDTF;
use Integrations::Echo;
use BromleyParks;
use Moo;
with 'FixMyStreet::Roles::CobrandEcho';
with 'FixMyStreet::Roles::CobrandPay360';

sub council_area_id { return 2482; }
sub council_area { return 'Bromley'; }
sub council_name { return 'Bromley Council'; }
sub council_url { return 'bromley'; }

sub report_validation {
    my ($self, $report, $errors) = @_;

    if ( length( $report->detail ) > 1750 ) {
        $errors->{detail} = sprintf( _('Reports are limited to %s characters in length. Please shorten your report'), 1750 );
    }

    return $errors;
}

sub problems_on_map_restriction {
    my ($self, $rs) = @_;
    return $rs if FixMyStreet->staging_flag('skip_checks');
    my $tfl = FixMyStreet::DB->resultset('Body')->search({ name => 'TfL' })->first;
    return $rs->to_body($tfl ? [ $self->body->id, $tfl->id ] : $self->body);
}

sub disambiguate_location {
    my $self    = shift;
    my $string  = shift;

    my $town = 'Bromley';

    #  There has been a road name change for a section of Ramsden Road
    #  (BR5) between Church Hill and Court Road has changed to 'Old Priory
    #  Avenue' - presently entering Old Priory Avenue simply takes the user to
    #  a different Priory Avenue in Petts Wood
    #  From Google maps search, "BR6 0PL" is a valid postcode for Old Priory Avenue
    if ($string =~/^old\s+priory\s+av\w*$/i) {
        $town = 'BR6 0PL';
    }

    # White Horse Hill is on boundary with Greenwich, so need a
    # specific postcode
    $town = 'BR7 6DH' if $string =~ /^white\s+horse/i;

    $town = '' if $string =~ /orpington/i;
    $string =~ s/(, *)?br[12]$//i;
    $town = 'Beckenham' if $string =~ s/(, *)?br3$//i;
    $town = 'West Wickham' if $string =~ s/(, *)?br4$//i;
    $town = 'Orpington' if $string =~ s/(, *)?br[56]$//i;
    $town = 'Chislehurst' if $string =~ s/(, *)?br7$//i;
    $town = 'Swanley' if $string =~ s/(, *)?br8$//i;

    return {
        %{ $self->SUPER::disambiguate_location() },
        string => $string,
        town => $town,
        centre => '51.366836,0.040623',
        span   => '0.154963,0.24347',
        bounds => [ 51.289355, -0.081112, 51.444318, 0.162358 ],
    };
}

sub get_geocoder {
    return 'OSM'; # default of Bing gives poor results, let's try overriding.
}

sub geocode_postcode {
    my ( $self, $s ) = @_;

    if (my $parks_lookup = BromleyParks::lookup($s)) {
        return $parks_lookup;
    }

    # split postcode with Lewisham
    if ($s =~ /BR1\s*4EY/i) {
        return {
            latitude => 51.4190772,
            longitude => 0.0117805,
        };
    }

    return $self->next::method($s);
}

# Bromley pins always yellow
sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'grey' if !$self->owns_problem( $p );
    return 'yellow';
}

sub recent_photos {
    my ( $self, $area, $num, $lat, $lon, $dist ) = @_;
    $num = 3 if $num > 3 && $area eq 'alert';
    return $self->problems->recent_photos( $num, $lat, $lon, $dist );
}

sub send_questionnaires {
    return 0;
}

sub ask_ever_reported {
    return 0;
}

sub process_open311_extras {
    my $self = shift;
    $self->SUPER::process_open311_extras( @_, [ 'first_name', 'last_name' ] );
}

sub abuse_reports_only { 1; }

sub reports_per_page { return 20; }

sub tweak_all_reports_map {
    my $self = shift;
    my $c = shift;

    if ( !$c->stash->{ward} ) {
        $c->stash->{map}->{longitude} = 0.040622967881348;
        $c->stash->{map}->{latitude} = 51.36690161822;
        $c->stash->{map}->{any_zoom} = 0;
        $c->stash->{map}->{zoom} = 11;
    }
}

sub title_list {
    return ["MR", "MISS", "MRS", "MS", "DR"];
}

sub waste_check_staff_payment_permissions {
    my $self = shift;
    my $c = $self->{c};


    return unless $c->stash->{is_staff};

    if ( $c->user->has_permission_to('can_pay_with_csc', $self->body->id) ) {
        $c->stash->{staff_payments_allowed} = 'paye';
    }
}

sub available_permissions {
    my $self = shift;

    my $perms = $self->next::method();
    $perms->{Waste}->{can_pay_with_csc} = "Can use CSC to pay for subscriptions";

    return $perms;
}

sub open311_config {
    my ($self, $row, $h, $params) = @_;

    $params->{always_send_latlong} = 0;
    $params->{send_notpinpointed} = 1;
    $params->{extended_description} = 0;
}

sub open311_extra_data_include {
    my ($self, $row, $h) = @_;

    my $title = $row->title;

    my $extra = $row->get_extra_fields;
    foreach (@$extra) {
        next unless $_->{value};
        $title .= ' | ID: ' . $_->{value} if $_->{name} eq 'feature_id';
        $title .= ' | PROW ID: ' . $_->{value} if $_->{name} eq 'prow_reference';
    }

    # Add contributing user's roles to report title
    my $contributed_by = $row->get_extra_metadata('contributed_by');
    my $contributing_user = FixMyStreet::DB->resultset('User')->find({ id => $contributed_by });
    my $roles;
    if ($contributing_user) {
        $roles = join(',', map { $_->name } $contributing_user->roles->all);
    }
    if ($roles) {
        $title .= ' | ROLES: ' . $roles;
    }

    my $open311_only = [
        { name => 'report_url',
          value => $h->{url} },
        { name => 'report_title',
          value => $title },
        { name => 'public_anonymity_required',
          value => $row->anonymous ? 'TRUE' : 'FALSE' },
        { name => 'email_alerts_requested',
          value => 'FALSE' }, # always false as can never request them
        { name => 'requested_datetime',
          value => DateTime::Format::W3CDTF->format_datetime($row->confirmed->set_nanosecond(0)) },
        { name => 'email',
          value => $row->user->email }
    ];

    if ( $row->category eq 'Garden Subscription' ) {
        if ( $row->get_extra_metadata('contributed_as') && $row->get_extra_metadata('contributed_as') eq 'anonymous_user' ) {
            push @$open311_only, { name => 'contributed_as', value => 'anonymous_user' };
        }
    }

    # make sure we have last_name attribute present in row's extra, so
    # it is passed correctly to Bromley as attribute[]
    if (!$row->get_extra_field_value('last_name')) {
        my ( $firstname, $lastname ) = ( $row->name =~ /(\S+)\.?\s+(.+)/ );
        push @$open311_only, { name => 'last_name', value => $lastname };
    }
    if (!$row->get_extra_field_value('fms_extra_title') && $row->user->title) {
        push @$open311_only, { name => 'fms_extra_title', value => $row->user->title };
    }

    return $open311_only;
}

sub open311_extra_data_exclude {
    [ 'feature_id', 'prow_reference' ]
}

sub open311_config_updates {
    my ($self, $params) = @_;
    $params->{endpoints} = {
        service_request_updates => 'update.xml',
        update => 'update.xml'
    } if $params->{endpoint} =~ /bromley.gov.uk/;
}

sub open311_pre_send {
    my ($self, $row, $open311) = @_;

    $self->_include_user_title_in_extra($row);

    $self->{bromley_original_detail} = $row->detail;

    my $private_comments = $row->get_extra_metadata('private_comments');
    if ($private_comments) {
        my $text = $row->detail . "\n\nPrivate comments: $private_comments";
        $row->detail($text);
    }
}

sub _include_user_title_in_extra {
    my ($self, $row) = @_;

    my $extra = $row->extra || {};
    unless ( $extra->{title} ) {
        $extra->{title} = $row->user->title;
        $row->extra( $extra );
    }
}

sub open311_pre_send_updates {
    my ($self, $row) = @_;

    $self->{bromley_original_update_text} = $row->text;

    my $private_comments = $row->get_extra_metadata('private_comments');
    if ($private_comments) {
        my $text = $row->text . "\n\nPrivate comments: $private_comments";
        $row->text($text);
    }

    return $self->_include_user_title_in_extra($row);
}

sub open311_post_send_updates {
    my ($self, $row) = @_;

    $row->text($self->{bromley_original_update_text});
}

sub open311_munge_update_params {
    my ($self, $params, $comment, $body) = @_;

    # Waste reports are sent to our Open311 endpoint, not Bromley's,
    # and we don't want to make changes to parameters in that case.
    return if $comment->problem->cobrand_data eq 'waste';

    delete $params->{update_id};
    $params->{public_anonymity_required} = $comment->anonymous ? 'TRUE' : 'FALSE',
    $params->{update_id_ext} = $comment->id;
    $params->{service_request_id_ext} = $comment->problem->id;
}

sub open311_post_send {
    my ($self, $row, $h, $sender) = @_;
    $row->detail($self->{bromley_original_detail});
    my $error = $sender->error;
    if ($error =~ /Cannot renew this property, a new request is required/ && $row->title eq "Garden Subscription - Renew") {
        # Was created as a renewal, but due to DD delay has now expired. Switch to new subscription
        $row->title("Garden Subscription - New");
        $row->update_extra_field({ name => "Subscription_Type", value => $self->waste_subscription_types->{New} });
    }
    if ($error =~ /Missed Collection event already open for the property/) {
        $row->state('duplicate');
    }
}

sub open311_contact_meta_override {
    my ($self, $service, $contact, $meta) = @_;

    $contact->set_extra_metadata( id_field => 'service_request_id_ext');

    my %server_set = (easting => 1, northing => 1, service_request_id_ext => 1);
    foreach (@$meta) {
        $_->{automated} = 'server_set' if $server_set{$_->{code}};
    }

    # Lights we want to store feature ID, PROW on all categories.
    push @$meta, {
        code => 'prow_reference',
        datatype => 'string',
        description => 'Right of way reference',
        order => 101,
        required => 'false',
        variable => 'true',
        automated => 'hidden_field',
    };
    push @$meta, {
        code => 'feature_id',
        datatype => 'string',
        description => 'Feature ID',
        order => 100,
        required => 'false',
        variable => 'true',
        automated => 'hidden_field',
    } if $service->{service_code} eq 'SLRS';

    my @override = qw(
        requested_datetime
        report_url
        title
        last_name
        email
        report_title
        public_anonymity_required
        email_alerts_requested
    );
    my %ignore = map { $_ => 1 } @override;
    @$meta = grep { !$ignore{$_->{code}} } @$meta;
}

sub should_skip_sending_update {
    my ($self, $update) = @_;

    my $private_comments = $update->get_extra_metadata('private_comments');

    return $update->user->from_body && !$update->text && !$private_comments;
}

sub updates_disallowed {
    my $self = shift;
    my ($problem) = @_;

    # No updates on waste reports
    return 'waste' if $problem->cobrand_data eq 'waste';

    return $self->next::method(@_);
}

sub clear_cached_lookups_property {
    my ($self, $id) = @_;

    my $key = "bromley:echo:look_up_property:$id";
    delete $self->{c}->session->{$key};
    $key = "bromley:echo:bin_services_for_address:$id";
    delete $self->{c}->session->{$key};
}

sub image_for_unit {
    my ($self, $unit) = @_;
    my $service_id = $unit->{service_id};
    my $base = '/cobrands/bromley/images/container-images';
    my $images = {
        531 => "$base/refuse-black-sack",
        532 => "$base/refuse-black-sack",
        533 => "$base/large-communal-black",
        535 => "$base/kerbside-green-box-mix",
        536 => "$base/small-communal-mix",
        537 => "$base/kerbside-black-box-paper",
        541 => "$base/small-communal-paper",
        542 => "$base/food-green-caddy",
        544 => "$base/food-communal",
        545 => "$base/garden-waste-bin",
    };
    return $images->{$service_id};
}

sub waste_staff_choose_payment_method { 0 }
sub waste_cheque_payments { 0 }

sub waste_event_state_map {
    return {
        New => { New => 'confirmed' },
        Pending => {
            Unallocated => 'investigating',
            'Allocated to Crew' => 'action scheduled',
            Accepted => 'action scheduled',
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

use constant GARDEN_WASTE_SERVICE_ID => 545;
sub garden_service_name { 'Green Garden Waste collection service' }
sub garden_service_id { GARDEN_WASTE_SERVICE_ID }
sub garden_current_subscription { shift->{c}->stash->{services}{+GARDEN_WASTE_SERVICE_ID} }
sub get_current_garden_bins { shift->garden_current_subscription->{garden_bins} }
sub garden_subscription_type_field { 'Subscription_Type' }
sub garden_subscription_container_field { 'Subscription_Details_Container_Type' }
sub garden_echo_container_name { 'LBB - GW Container' }

sub garden_current_service_from_service_units {
    my ($self, $services) = @_;

    my $garden;
    for my $service ( @$services ) {
        if ( $service->{ServiceId} == GARDEN_WASTE_SERVICE_ID ) {
            $garden = $self->_get_current_service_task($service);
            last;
        }
    }

    return $garden;
}

sub service_name_override {
    my ($self, $service) = @_;

    my %service_name_override = (
        531 => 'Non-Recyclable Refuse',
        532 => 'Non-Recyclable Refuse',
        533 => 'Non-Recyclable Refuse',
        535 => 'Mixed Recycling (Cans, Plastics & Glass)',
        536 => 'Mixed Recycling (Cans, Plastics & Glass)',
        537 => 'Paper & Cardboard',
        541 => 'Paper & Cardboard',
        542 => 'Food Waste',
        544 => 'Food Waste',
        545 => 'Garden Waste',
    );

    return $service_name_override{$service->{ServiceId}} || $service->{ServiceName};
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
        1 => 'Green Box (Plastic)',
        3 => 'Wheeled Bin (Plastic)',
        12 => 'Black Box (Paper)',
        14 => 'Wheeled Bin (Paper)',
        9 => 'Kitchen Caddy',
        10 => 'Outside Food Waste Container',
        44 => 'Garden Waste Container',
        46 => 'Wheeled Bin (Food)',
    };

    $self->{c}->stash->{container_actions} = $self->waste_container_actions;

    my %service_to_containers = (
        535 => [ 1 ],
        536 => [ 3 ],
        537 => [ 12 ],
        541 => [ 14 ],
        542 => [ 9, 10 ],
        544 => [ 46 ],
        545 => [ 44 ],
    );
    my %request_allowed = map { $_ => 1 } keys %service_to_containers;
    my %quantity_max = (
        535 => 6,
        536 => 4,
        537 => 6,
        541 => 4,
        542 => 6,
        544 => 4,
        545 => 6,
    );

    $self->{c}->stash->{quantity_max} = \%quantity_max;

    $self->{c}->stash->{garden_subs} = $self->waste_subscription_types;

    my $result = $self->{api_serviceunits};
    return [] unless @$result;

    my $events = $self->_parse_events($self->{api_events});
    $self->{c}->stash->{open_service_requests} = $events->{enquiry};

    # If there is an open Garden subscription (2106) event, assume
    # that means a bin is being delivered and so a pending subscription
    $self->{c}->stash->{pending_subscription} = $events->{enquiry}{2106} ? { title => 'Garden Subscription - New' } : undef;

    my @to_fetch;
    my %schedules;
    my @task_refs;
    my %expired;
    foreach (@$result) {
        my $servicetask = $self->_get_current_service_task($_) or next;
        my $schedules = _parse_schedules($servicetask);
        $expired{$_->{Id}} = $schedules if $self->waste_sub_overdue( $schedules->{end_date}, weeks => 4 );

        next unless $schedules->{next} or $schedules->{last};
        $schedules{$_->{Id}} = $schedules;
        push @to_fetch, GetEventsForObject => [ ServiceUnit => $_->{Id} ];
        push @task_refs, $schedules->{last}{ref} if $schedules->{last};
    }
    push @to_fetch, GetTasks => \@task_refs if @task_refs;

    my $cfg = $self->feature('echo');
    my $echo = Integrations::Echo->new(%$cfg);
    my $calls = $echo->call_api($self->{c}, 'bromley', 'bin_services_for_address:' . $property->{id}, @to_fetch);

    my @out;
    my %task_ref_to_row;
    foreach (@$result) {
        my $service_id = $_->{ServiceId};
        my $service_name = $self->service_name_override($_);
        next unless $schedules{$_->{Id}} || ( $service_name eq 'Garden Waste' && $expired{$_->{Id}} );

        my $schedules = $schedules{$_->{Id}} || $expired{$_->{Id}};
        my $servicetask = $self->_get_current_service_task($_);

        my $containers = $service_to_containers{$service_id};
        my ($open_request) = grep { $_ } map { $events->{request}->{$_} } @$containers;

        my $request_max = $quantity_max{$service_id};

        my $garden = 0;
        my $garden_bins;
        my $garden_cost = 0;
        my $garden_due = $self->waste_sub_due($schedules->{end_date});
        my $garden_overdue = $expired{$_->{Id}};
        if ($service_name eq 'Garden Waste') {
            $garden = 1;
            my $data = Integrations::Echo::force_arrayref($servicetask->{Data}, 'ExtensibleDatum');
            foreach (@$data) {
                next unless $_->{DatatypeName} eq 'LBB - GW Container'; # DatatypeId 5093
                my $moredata = Integrations::Echo::force_arrayref($_->{ChildData}, 'ExtensibleDatum');
                foreach (@$moredata) {
                    # $container = $_->{Value} if $_->{DatatypeName} eq 'Container'; # should be 44
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
            service_task_id => $servicetask->{Id},
            service_task_name => $servicetask->{TaskTypeName},
            service_task_type_id => $servicetask->{TaskTypeId},
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

    $self->waste_task_resolutions($calls->{GetTasks}, \%task_ref_to_row);

    return \@out;
}

sub _closed_event {
    my $event = shift;
    return 1 if $event->{ResolvedDate};
    return 1 if $event->{ResolutionCodeId} && $event->{ResolutionCodeId} != 584; # Out of Stock
    return 0;
}

sub _parse_events {
    my $self = shift;
    my $events_data = shift;
    my $events;
    foreach (@$events_data) {
        my $event_type = $_->{EventTypeId};
        my $type = 'enquiry';
        $type = 'request' if $event_type == 2104;
        $type = 'missed' if 2095 <= $event_type && $event_type <= 2103;

        # Only care about open requests/enquiries
        my $closed = _closed_event($_);
        next if $type ne 'missed' && $closed;

        if ($type eq 'request') {
            my $data = $_->{Data} ? $_->{Data}{ExtensibleDatum} : [];
            my $container;
            DATA: foreach (@$data) {
                if ($_->{ChildData}) {
                    foreach (@{$_->{ChildData}{ExtensibleDatum}}) {
                        if ($_->{DatatypeName} eq 'Container Type') {
                            $container = $_->{Value};
                            last DATA;
                        }
                    }
                }
            }
            my $report = $self->problems->search({ external_id => $_->{Guid} })->first;
            $events->{request}->{$container} = $report ? { report => $report } : 1;
        } elsif ($type eq 'missed') {
            my $report = $self->problems->search({ external_id => $_->{Guid} })->first;
            my $service_id = $_->{ServiceId};
            my $data = {
                closed => $closed,
                date => construct_bin_date($_->{EventDate}),
            };
            $data->{report} = $report if $report;
            push @{$events->{missed}->{$service_id}}, $data;
        } else { # General enquiry of some sort
            $events->{enquiry}->{$event_type} = 1;
        }
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

    $c->set_param('Subscription_Type', $type);
    $c->set_param('Subscription_Details_Container_Type', $container_types{'Garden Waste Container'});
    $c->set_param('Subscription_Details_Quantity', $data->{bin_count});
    if ( $data->{new_bins} ) {
        if ( $data->{new_bins} > 0 ) {
            $c->set_param('Container_Instruction_Action', $c->stash->{container_actions}->{deliver} );
        } elsif ( $data->{new_bins} < 0 ) {
            $c->set_param('Container_Instruction_Action',  $c->stash->{container_actions}->{remove} );
        }
        $c->set_param('Container_Instruction_Container_Type', $container_types{'Garden Waste Container'});
        $c->set_param('Container_Instruction_Quantity', abs($data->{new_bins}));
    }

    $self->_set_user_source;
}

sub garden_waste_dd_get_redirect_params {
    my ($self, $c) = @_;

    my $token = $c->get_param('reference');
    my $id = $c->get_param('report_id');

    return ($token, $id);
}

sub garden_waste_check_pending {
    my ($self, $report) = @_;
    return $report;
}


sub _set_user_source {
    my $self = shift;
    my $c = $self->{c};
    return if !$c->user_exists || !$c->user->from_body;

    my %roles = map { $_->name => 1 } $c->user->obj->roles->all;
    my $source = 9; # Client Officer
    $source = 3 if $roles{'Contact Centre Agent'} || $roles{'CSC'}; # Council Contact Centre
    $c->set_param('Source', $source);
}

sub waste_munge_request_data {
    my ($self, $id, $data) = @_;

    my $c = $self->{c};

    my $address = $c->stash->{property}->{address};
    my $container = $c->stash->{containers}{$id};
    my $quantity = $data->{"quantity-$id"};
    my $reason = $data->{replacement_reason} || '';
    $data->{title} = "Request new $container";
    $data->{detail} = "Quantity: $quantity\n\n$address";
    $c->set_param('Container_Type', $id);
    $c->set_param('Quantity', $quantity);
    if ($id == 44) {
        if ($reason eq 'damaged') {
            $c->set_param('Action', '2::1'); # Remove/Deliver
            $c->set_param('Reason', 3); # Damaged
        } elsif ($reason eq 'stolen' || $reason eq 'taken') {
            $c->set_param('Reason', 1); # Missing / Stolen
        }
    } else {
        # Don't want to be remembered from previous loop
        $c->set_param('Action', '');
        $c->set_param('Reason', '');
    }
    $self->_set_user_source;
}

sub waste_munge_report_data {
    my ($self, $id, $data) = @_;

    my $c = $self->{c};

    my $address = $c->stash->{property}->{address};
    my $service = $c->stash->{services}{$id}{service_name};
    $data->{title} = "Report missed $service";
    $data->{detail} = "$data->{title}\n\n$address";
    $c->set_param('service_id', $id);
    $self->_set_user_source;
}

sub waste_munge_enquiry_data {
    my ($self, $data) = @_;

    my $address = $self->{c}->stash->{property}->{address};
    $data->{title} = $data->{category};

    my $detail;
    foreach (grep { /^extra_/ } keys %$data) {
        $detail .= "$data->{$_}\n\n";
    }
    $detail .= $address;
    $data->{detail} = $detail;
    $self->_set_user_source;
}

sub waste_get_pro_rata_cost {
    my ($self, $bins, $end) = @_;

    my $now = DateTime->now->set_time_zone(FixMyStreet->local_time_zone);
    my $sub_end = DateTime::Format::W3CDTF->parse_datetime($end);
    my $cost = $bins * $self->waste_get_pro_rata_bin_cost( $sub_end, $now );

    return $cost;
}

sub waste_get_pro_rata_bin_cost {
    my ($self, $end, $start) = @_;

    my $weeks = $end->delta_days($start)->in_units('weeks');
    $weeks -= 1 if $weeks > 0;

    my $base = $self->feature('payment_gateway')->{pro_rata_minimum};
    my $weekly_cost = $self->feature('payment_gateway')->{pro_rata_weekly};

    my $cost = $base + ( $weeks * $weekly_cost );

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

    return $self->feature('payment_gateway')->{ggw_cost} * $bin_count;
}

sub garden_waste_new_bin_admin_fee { 0 }

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

sub dashboard_export_problems_add_columns {
    my ($self, $csv) = @_;

    $csv->add_csv_columns(
        staff_user => 'Staff User',
        staff_role => 'Staff Role',
    );

    my $user_lookup = $self->csv_staff_users;

    my $userroles = FixMyStreet::DB->resultset("UserRole")->search({
        user_id => [ keys %$user_lookup ],
    }, {
        prefetch => 'role'
    });
    my %userroles;
    while (my $userrole = $userroles->next) {
        my $user_id = $userrole->user_id;
        my $role = $userrole->role->name;
        push @{$userroles{$user_id}}, $role;
    }

    $csv->csv_extra_data(sub {
        my $report = shift;

        my $by = $report->get_extra_metadata('contributed_by');
        my $staff_user = '';
        my $staff_role = '';
        if ($by) {
            $staff_user = $self->csv_staff_user_lookup($by, $user_lookup);
            $staff_role = join(',', @{$userroles{$by} || []});
        }
        return {
            staff_user => $staff_user,
            staff_role => $staff_role,
        };
    });
}

sub report_form_extras {
    ( { name => 'private_comments' } )
}

1;
