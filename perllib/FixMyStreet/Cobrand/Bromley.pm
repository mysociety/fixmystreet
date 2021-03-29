package FixMyStreet::Cobrand::Bromley;
use parent 'FixMyStreet::Cobrand::UKCouncils';

use strict;
use warnings;
use utf8;
use DateTime::Format::W3CDTF;
use DateTime::Format::Flexible;
use File::Temp;
use Integrations::Echo;
use JSON::MaybeXS;
use Parallel::ForkManager;
use Sort::Key::Natural qw(natkeysort_inplace);
use Storable;
use Try::Tiny;
use FixMyStreet::DateRange;
use FixMyStreet::WorkingDays;
use Open311::GetServiceRequestUpdates;
use Memcached;

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

# This makes sure that the subcategory Open311 attribute question is
# also stored in the report's subcategory column. This could be done
# in process_open311_extras, but seemed easier to keep that separate
sub report_new_munge_before_insert {
    my ($self, $report) = @_;

    # Make sure TfL reports are marked safety critical
    $self->SUPER::report_new_munge_before_insert($report);

    $report->subcategory($report->get_extra_field_value('service_sub_code'));
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

sub map_type {
    'Bromley';
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

    # A place where this can happen
    return unless $c->action eq 'dashboard/heatmap';

    # Bromley uses an extra attribute question to store 'subcategory',
    # rather than group/category, but wants this extra question to act
    # like a subcategory e.g. in the dashboard filter here.
    my %subcats = $self->subcategories;
    my $groups = $c->stash->{category_groups};
    foreach (@$groups) {
        my $filter = $_->{categories};
        my @new_contacts;
        foreach (@$filter) {
            push @new_contacts, $_;
            foreach (@{$subcats{$_->id}}) {
                push @new_contacts, {
                    category => $_->{key},
                    category_display => (" " x 4) . $_->{name},
                };
            }
        }
        $_->{categories} = \@new_contacts;
    }

    if (!%{$c->stash->{filter_category}}) {
        my $cats = $c->user->categories;
        my $subcats = $c->user->get_extra_metadata('subcategories') || [];
        $c->stash->{filter_category} = { map { $_ => 1 } @$cats, @$subcats } if @$cats || @$subcats;
    }
}

sub title_list {
    return ["MR", "MISS", "MRS", "MS", "DR"];
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

    my $extra = $row->extra || {};
    unless ( $extra->{title} ) {
        $extra->{title} = $row->user->title;
        $row->extra( $extra );
    }
}

sub open311_pre_send_updates {
    my ($self, $row) = @_;
    return $self->open311_pre_send($row);
}

sub open311_munge_update_params {
    my ($self, $params, $comment, $body) = @_;
    delete $params->{update_id};
    $params->{public_anonymity_required} = $comment->anonymous ? 'TRUE' : 'FALSE',
    $params->{update_id_ext} = $comment->id;
    $params->{service_request_id_ext} = $comment->problem->id;
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

# If any subcategories ticked in user edit admin, make sure they're saved.
sub admin_user_edit_extra_data {
    my $self = shift;
    my $c = $self->{c};
    my $user = $c->stash->{user};

    return unless $c->get_param('submit') && $user && $user->from_body;

    $c->stash->{body} = $user->from_body;
    my %subcats = $self->subcategories;
    my @subcat_ids = map { $_->{key} } map { @$_ } values %subcats;
    my @new_contact_ids = grep { $c->get_param("contacts[$_]") } @subcat_ids;
    $user->set_extra_metadata('subcategories', \@new_contact_ids);
}

# Returns a hash of contact ID => list of subcategories
# (which are stored as Open311 attribute questions)
sub subcategories {
    my $self = shift;

    my @c = $self->body->contacts->not_deleted->all;
    my %subcategories;
    foreach my $contact (@c) {
        my @fields = @{$contact->get_extra_fields};
        my ($field) = grep { $_->{code} eq 'service_sub_code' } @fields;
        $subcategories{$contact->id} = $field->{values} || [];
    }
    return %subcategories;
}

# Returns the list of categories, with Bromley subcategories added,
# for the user edit admin interface
sub add_admin_subcategories {
    my $self = shift;
    my $c = $self->{c};

    my $user = $c->stash->{user};
    return $c->stash->{contacts} unless $user; # e.g. admin templates, not user

    my @subcategories = @{$user->get_extra_metadata('subcategories') || []};
    my %active_contacts = map { $_ => 1 } @subcategories;

    my %subcats = $self->subcategories;
    my $contacts = $c->stash->{contacts};
    my @new_contacts;
    foreach (@$contacts) {
        push @new_contacts, $_;
        foreach (@{$subcats{$_->{id}}}) {
            push @new_contacts, {
                id => $_->{key},
                category => (" " x 4) . $_->{name}, # nbsp
                active => $active_contacts{$_->{key}},
            };
        }
    }
    return \@new_contacts;
}

# On heatmap page, include querying on subcategories
sub munge_load_and_group_problems {
    my ($self, $where, $filter) = @_;
    my $c = $self->{c};

    return unless $c->action eq 'dashboard/heatmap';

    # Bromley subcategory stuff
    if (!$where->{'me.category'}) {
        my $cats = $c->user->categories;
        my $subcats = $c->user->get_extra_metadata('subcategories') || [];
        $where->{'me.category'} = [ @$cats, @$subcats ] if @$cats || @$subcats;
    }

    my %subcats = $self->subcategories;
    my $subcat;
    my %chosen = map { $_ => 1 } @{$where->{'me.category'} || []};
    my @subcat = grep { $chosen{$_} } map { $_->{key} } map { @$_ } values %subcats;
    if (@subcat) {
        my %chosen = map { $_ => 1 } @subcat;
        $where->{'-or'} = {
            'me.category' => [ grep { !$chosen{$_} } @{$where->{'me.category'}} ],
            'me.subcategory' => \@subcat,
        };
        delete $where->{'me.category'};
    }
}

# We want to send confirmation emails only for Waste reports
sub report_sent_confirmation_email {
    my ($self, $report) = @_;
    my $contact = $report->contact or return;
    return 'id' if grep { $_ eq 'Waste' } @{$report->contact->groups};
    return '';
}

sub munge_around_category_where {
    my ($self, $where) = @_;
    $where->{extra} = [ undef, { -not_like => '%Waste%' } ];
}

sub munge_reports_category_list {
    my ($self, $categories) = @_;
    @$categories = grep { grep { $_ ne 'Waste' } @{$_->groups} } @$categories;
}

sub munge_report_new_contacts {
    my ($self, $categories) = @_;

    return if $self->{c}->action =~ /^waste/;

    @$categories = grep { grep { $_ ne 'Waste' } @{$_->groups} } @$categories;
    $self->SUPER::munge_report_new_contacts($categories);
}

sub updates_disallowed {
    my $self = shift;
    my ($problem) = @_;

    # No updates on waste reports
    return 'waste' if $problem->cobrand_data eq 'waste';

    return $self->next::method(@_);
}

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
    my ($self, $id, $staff) = @_;

    my $cfg = $self->feature('echo');
    if ($cfg->{max_per_day} && !$staff) {
        my $today = DateTime->today->set_time_zone(FixMyStreet->local_time_zone)->ymd;
        my $ip = $self->{c}->req->address;
        my $key = FixMyStreet->test_mode ? "bromley-test" : "bromley-$ip-$today";
        my $count = Memcached::increment($key, 86400) || 0;
        $self->{c}->detach('/page_error_403_access_denied', []) if $count > $cfg->{max_per_day};
    }

    my $calls = $self->call_api(
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

sub image_for_service {
    my ($self, $service_id) = @_;
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

sub bin_services_for_address {
    my $self = shift;
    my $property = shift;

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

    $self->{c}->stash->{containers} = {
        1 => 'Green Box (Plastic)',
        3 => 'Wheeled Bin (Plastic)',
        12 => 'Black Box (Paper)',
        14 => 'Wheeled Bin (Paper)',
        9 => 'Kitchen Caddy',
        10 => 'Outside Food Waste Container',
        46 => 'Wheeled Bin (Food)',
    };
    my %service_to_containers = (
        535 => [ 1 ],
        536 => [ 3 ],
        537 => [ 12 ],
        541 => [ 14 ],
        542 => [ 9, 10 ],
        544 => [ 46 ],
    );
    my %request_allowed = map { $_ => 1 } keys %service_to_containers;
    my %quantity_max = (
        535 => 6,
        536 => 4,
        537 => 6,
        541 => 4,
        542 => 6,
        544 => 4,
    );

    my $result = $self->{api_serviceunits};
    return [] unless @$result;

    my $events = $self->{api_events};
    my $open = $self->_parse_open_events($events);

    my @to_fetch;
    my %schedules;
    my @task_refs;
    foreach (@$result) {
        next unless $_->{ServiceTasks};

        my $servicetask = $_->{ServiceTasks}{ServiceTask};
        my $schedules = _parse_schedules($servicetask);

        next unless $schedules->{next} or $schedules->{last};
        $schedules{$_->{Id}} = $schedules;
        push @to_fetch, GetEventsForObject => [ ServiceUnit => $_->{Id} ];
        push @task_refs, $schedules->{last}{ref} if $schedules->{last};
    }
    push @to_fetch, GetTasks => \@task_refs if @task_refs;

    my $calls = $self->call_api(@to_fetch);

    my @out;
    my %task_ref_to_row;
    foreach (@$result) {
        next unless $schedules{$_->{Id}};
        my $schedules = $schedules{$_->{Id}};
        my $servicetask = $_->{ServiceTasks}{ServiceTask};

        my $events = $calls->{"GetEventsForObject ServiceUnit $_->{Id}"};
        my $open_unit = $self->_parse_open_events($events);

        my $containers = $service_to_containers{$_->{ServiceId}};
        my ($open_request) = grep { $_ } map { $open->{request}->{$_} } @$containers;
        my $row = {
            id => $_->{Id},
            service_id => $_->{ServiceId},
            service_name => $service_name_override{$_->{ServiceId}} || $_->{ServiceName},
            report_open => $open->{missed}->{$_->{ServiceId}} || $open_unit->{missed}->{$_->{ServiceId}},
            request_allowed => $request_allowed{$_->{ServiceId}},
            request_open => $open_request,
            request_containers => $containers,
            request_max => $quantity_max{$_->{ServiceId}},
            enquiry_open_events => $open->{enquiry},
            service_task_id => $servicetask->{Id},
            service_task_name => $servicetask->{TaskTypeName},
            service_task_type_id => $servicetask->{TaskTypeId},
            schedule => $schedules->{description},
            last => $schedules->{last},
            next => $schedules->{next},
        };
        if ($row->{last}) {
            my $ref = join(',', @{$row->{last}{ref}});
            $task_ref_to_row{$ref} = $row;
        }
        push @out, $row;
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
            $row->{last}{state} = $state;
            $row->{last}{completed} = $completed;
            $row->{last}{resolution} = $resolution;
            $row->{report_allowed} = within_working_days($row->{last}{date}, 2);

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

sub _parse_open_events {
    my $self = shift;
    my $events = shift;
    my $open;
    foreach (@$events) {
        next if $_->{ResolvedDate};
        next if $_->{ResolutionCodeId} && $_->{ResolutionCodeId} != 584; # Out of Stock
        my $event_type = $_->{EventTypeId};
        my $service_id = $_->{ServiceId};
        if ($event_type == 2104) { # Request
            my $data = $_->{Data}{ExtensibleDatum};
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
            $open->{request}->{$container} = $report ? { report => $report } : 1;
        } elsif (2095 <= $event_type && $event_type <= 2103) { # Missed collection
            my $report = $self->problems->search({ external_id => $_->{Guid} })->first;
            $open->{missed}->{$service_id} = $report ? { report => $report } : 1;
        } else { # General enquiry of some sort
            $open->{enquiry}->{$event_type} = 1;
        }
    }
    return $open;
}

sub _parse_schedules {
    my $servicetask = shift;
    return unless $servicetask->{ServiceTaskSchedules};
    my $schedules = $servicetask->{ServiceTaskSchedules}{ServiceTaskSchedule};
    $schedules = [ $schedules ] unless ref $schedules eq 'ARRAY';

    my $today = DateTime->now->set_time_zone(FixMyStreet->local_time_zone)->strftime("%F");
    my ($min_next, $max_last, $next_changed, $description);
    foreach my $schedule (@$schedules) {
        my $end_date = construct_bin_date($schedule->{EndDate})->strftime("%F");
        next if $end_date lt $today;

        $description = $schedule->{ScheduleDescription};

        my $next = $schedule->{NextInstance};
        my $d = construct_bin_date($next->{CurrentScheduledDate});
        if ($d && (!$min_next || $d < $min_next->{date})) {
            $next_changed = $next->{CurrentScheduledDate}{DateTime} ne $next->{OriginalScheduledDate}{DateTime};
            $min_next = {
                date => $d,
                ordinal => ordinal($d->day),
                changed => $next_changed,
            };
        }

        my $last = $schedule->{LastInstance};
        $d = construct_bin_date($last->{CurrentScheduledDate});
        # It is possible the last instance for this schedule has been rescheduled to
        # be in the future. If so, we should treat it like it is a next instance.
        if ($d && $d->strftime("%F") gt $today && (!$min_next || $d < $min_next->{date})) {
            my $last_changed = $last->{CurrentScheduledDate}{DateTime} ne $last->{OriginalScheduledDate}{DateTime};
            $min_next = {
                date => $d,
                ordinal => ordinal($d->day),
                changed => $last_changed,
            };
        } elsif ($d && (!$max_last || $d > $max_last->{date})) {
            my $last_changed = $last->{CurrentScheduledDate}{DateTime} ne $last->{OriginalScheduledDate}{DateTime};
            $max_last = {
                date => $d,
                ordinal => ordinal($d->day),
                changed => $last_changed,
                ref => $last->{Ref}{Value}{anyType},
            };
        }
    }

    return {
        next => $min_next,
        last => $max_last,
        description => $description,
    };
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

=over

=item within_working_days

Given a DateTime object and a number, return true if today is less than or
equal to that number of working days (excluding weekends and bank holidays)
after the date.

=cut

sub within_working_days {
    my ($dt, $days) = @_;
    my $wd = FixMyStreet::WorkingDays->new(public_holidays => FixMyStreet::Cobrand::UK::public_holidays());
    $dt = $wd->add_days($dt, $days)->ymd;
    my $today = DateTime->now->set_time_zone(FixMyStreet->local_time_zone)->ymd;
    return $today le $dt;
}

=item waste_fetch_events

Loop through all open waste events to see if there have been any updates

=back

=cut

sub waste_fetch_events {
    my ($self, $verbose) = @_;

    my $body = $self->body;
    my @contacts = $body->contacts->search({
        send_method => 'Open311',
        endpoint => { '!=', '' },
    })->all;
    die "Could not find any devolved contacts\n" unless @contacts;

    my %open311_conf = (
        endpoint => $contacts[0]->endpoint || '',
        api_key => $contacts[0]->api_key || '',
        jurisdiction => $contacts[0]->jurisdiction || '',
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
        suppress_alerts => 0,
        blank_updates_permitted => $body->blank_updates_permitted,
    );

    my $echo = $self->feature('echo');
    $echo = Integrations::Echo->new(%$echo);

    my $cfg = {
        verbose => $verbose,
        updates => $updates,
        echo => $echo,
        event_types => {},
    };

    my $reports = $self->problems->search({
        external_id => { '!=', '' },
        state => [ FixMyStreet::DB::Result::Problem->open_states() ],
        category => [ map { $_->category } @contacts ],
    });

    while (my $report = $reports->next) {
        print 'Fetching data for report ' . $report->id . "\n" if $verbose;

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

    my $event_type = $cfg->{event_types}{$event->{EventTypeId}} ||= $self->waste_get_event_type($cfg, $event->{EventTypeId});
    my $state_id = $event->{EventStateId};
    my $resolution_id = $event->{ResolutionCodeId} || '';
    my $status = $event_type->{states}{$state_id}{state};
    my $description = $event_type->{resolution}{$resolution_id} || $event_type->{states}{$state_id}{name};
    return {
        description => $description,
        status => $status,
        update_id => 'waste',
        external_status_code => "$resolution_id,,",
    };
}

sub waste_get_event_type {
    my ($self, $cfg, $id) = @_;

    my $event_type = $cfg->{echo}->GetEventType($id);

    my $state_map = {
        New => { New => 'confirmed' },
        Pending => {
            Unallocated => 'investigating',
            'Allocated to Crew' => 'action scheduled',
        },
        Closed => {
            Closed => 'fixed - council',
            Completed => 'fixed - council',
            'Not Completed' => 'unable to fix',
            Rejected => 'closed',
        },
    };

    my $states = $event_type->{Workflow}->{States}->{State};
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

sub admin_templates_external_status_code_hook {
    my ($self) = @_;
    my $c = $self->{c};

    my $res_code = $c->get_param('resolution_code') || '';
    my $task_type = $c->get_param('task_type') || '';
    my $task_state = $c->get_param('task_state') || '';

    return "$res_code,$task_type,$task_state";
}

sub call_api {
    my $self = shift;

    my $tmp = File::Temp->new;
    my @cmd = (
        FixMyStreet->path_to('bin/fixmystreet.com/bromley-echo'),
        '--out', $tmp,
        '--calls', encode_json(\@_),
    );

    # We cannot fork directly under mod_fcgid, so
    # call an external script that calls back in.
    my $data;
    my $echo = $self->feature('echo');
    # uncoverable branch false
    if (FixMyStreet->test_mode || $echo->{sample_data}) {
        $data = $self->_parallel_api_calls(@_);
    } else {
        # uncoverable statement
        system(@cmd);
        $data = Storable::fd_retrieve($tmp);
    }
    return $data;
}

sub _parallel_api_calls {
    my $self = shift;
    my $echo = $self->feature('echo');
    $echo = Integrations::Echo->new(%$echo);

    my %calls;
    # uncoverable branch false
    my $pm = Parallel::ForkManager->new(FixMyStreet->test_mode || $echo->sample_data ? 0 : 10);
    $pm->run_on_finish(sub {
        my ($pid, $exit_code, $ident, $exit_signal, $core_dump, $data) = @_;
        %calls = ( %calls, %$data );
    });

    while (@_) {
        my $call = shift;
        my $args = shift;
        $pm->start and next;
        my $result = $echo->$call(@$args);
        my $key = "$call @$args";
        $key = $call if $call eq 'GetTasks';
        $pm->finish(0, { $key => $result });
    }
    $pm->wait_all_children;

    return \%calls;
}

1;
